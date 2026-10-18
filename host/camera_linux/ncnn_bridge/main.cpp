// Isolated CPU-only bridge for the exported decoded YOLOv8n in0/out0 head.
#include <net.h>
#include <layer.h>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

struct Box { int id; float score, x1, y1, x2, y2; };
float overlap(const Box& a, const Box& b) {
    float intersection = std::max(0.f, std::min(a.x2,b.x2)-std::max(a.x1,b.x1)) *
                         std::max(0.f, std::min(a.y2,b.y2)-std::max(a.y1,b.y1));
    return intersection / std::max(1e-9f, (a.x2-a.x1)*(a.y2-a.y1) +
                                  (b.x2-b.x1)*(b.y2-b.y1)-intersection);
}
int main(int argc, char** argv) {
    if (argc != 6) { std::cerr << "MODEL_DIR SIZE THREADS CONF IOU\n"; return 2; }
    const int size = std::stoi(argv[2]), threads = std::stoi(argv[3]);
    const float conf = std::stof(argv[4]), iou = std::stof(argv[5]);
    if (size < 32 || size % 32 || threads < 1 || threads > 4 || conf <= 0 || conf > 1 || iou <= 0 || iou > 1)
        return 2;
    // These helpers are created indirectly by Mat/convolution, outside .param.
    // Refuse an incomplete trimmed NCNN build before a null helper can crash.
    const char* helpers[] = {"Scale","Bias","Flatten","InnerProduct","Packing","Cast",
                             "Padding","Crop","Interp","ReLU","Clip","Sigmoid","Mish","HardSwish"};
    for (const char* name:helpers) {
        ncnn::Layer* layer=ncnn::create_layer(name);
        if (!layer) { std::cerr << "Required NCNN helper unavailable: " << name << '\n'; return 3; }
        delete layer;
    }
    ncnn::Net net;
    net.opt.num_threads = threads;
    net.opt.use_vulkan_compute = false;
    net.opt.use_fp16_storage = false;
    net.opt.use_fp16_arithmetic = false;
    const std::string dir(argv[1]);
    if (net.load_param((dir+"/model.ncnn.param").c_str()) ||
        net.load_model((dir+"/model.ncnn.bin").c_str())) return 3;
    cv::setNumThreads(1);
    std::cerr << "NCNN_CPU_READY requested_threads=" << threads << " input=" << size;
#ifdef _OPENMP
    std::cerr << " openmp=enabled\n";
#else
    std::cerr << " openmp=disabled effective_threads=1\n";
#endif
    std::string line;
    while (std::getline(std::cin, line)) {
        try {
            std::string path;
            std::istringstream request(line);
            if (!(request >> std::quoted(path)) || path.empty() || path[0] != '/')
                throw std::runtime_error("invalid image path");
            cv::Mat image = cv::imread(path, cv::IMREAD_COLOR);
            if (image.empty()) throw std::runtime_error("image decode failed");
            const auto start = std::chrono::steady_clock::now();
            float scale = std::min(float(size)/image.rows, float(size)/image.cols);
            int nw = std::round(image.cols*scale), nh = std::round(image.rows*scale);
            int left = (size-nw)/2, top = (size-nh)/2;
            cv::Mat resized, padded;
            cv::resize(image, resized, cv::Size(nw, nh));
            cv::copyMakeBorder(resized,padded,top,size-nh-top,left,size-nw-left,
                               cv::BORDER_CONSTANT,cv::Scalar(114,114,114));
            ncnn::Mat input = ncnn::Mat::from_pixels(padded.data, ncnn::Mat::PIXEL_BGR2RGB, size,size);
            const float normalization[3] = {1/255.f,1/255.f,1/255.f};
            input.substract_mean_normalize(nullptr,normalization);
            auto extractor = net.create_extractor();
            ncnn::Mat out;
            if (extractor.input("in0",input) || extractor.extract("out0",out))
                throw std::runtime_error("NCNN extraction failed");
            if (out.dims != 2 || (out.h != 84 && out.w != 84))
                throw std::runtime_error("expected decoded 84xN or Nx84 output");
            bool rows = out.w == 84;
            int count = rows ? out.h : out.w;
            auto value = [&](int anchor, int field) -> float {
                return rows ? out.row(anchor)[field] : out.row(field)[anchor];
            };
            std::vector<Box> boxes;
            for (int n=0; n<count; n++) {
                float score=0; int id=-1;
                for (int c=0;c<80;c++) {
                    float p=value(n,c+4);
                    if (!std::isfinite(p)) throw std::runtime_error("nonfinite class output");
                    if (p>score) { score=p; id=c; }
                }
                if (score < conf) continue;
                float x=value(n,0),y=value(n,1),w=value(n,2),h=value(n,3);
                if (!std::isfinite(x+y+w+h)) throw std::runtime_error("nonfinite box output");
                Box b{id,score,std::max(0.f,(x-w/2-left)/scale),std::max(0.f,(y-h/2-top)/scale),
                      std::min(float(image.cols),(x+w/2-left)/scale),
                      std::min(float(image.rows),(y+h/2-top)/scale)};
                if (b.x2>b.x1 && b.y2>b.y1) boxes.push_back(b);
            }
            std::sort(boxes.begin(), boxes.end(), [](const Box& a,const Box& b){return a.score>b.score;});
            std::vector<Box> kept;
            for (const auto& b:boxes) {
                bool suppress=false;
                for (const auto& a:kept) if(a.id==b.id && overlap(a,b)>iou) {suppress=true;break;}
                if (!suppress) kept.push_back(b);
            }
            double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
            std::cout << std::setprecision(8) << "{\"inference_ms\":" << ms << ",\"detections\":[";
            bool first=true;
            for (const auto& b:kept) {
                if(!first) std::cout << ',';
                first=false;
                std::cout << '[' << b.id << ',' << b.score << ',' << b.x1 << ',' << b.y1 << ',' << b.x2 << ',' << b.y2 << ']';
            }
            std::cout << "]}" << std::endl;
        } catch(const std::exception& error) {
            std::cerr << "NCNN_ERROR " << error.what() << '\n';
            std::cout << "{\"error\":\"native inference failed; see bridge diagnostics\"}" << std::endl;
        }
    }
}
