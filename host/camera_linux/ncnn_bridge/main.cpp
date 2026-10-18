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
#include <ctime>
#include <cstdint>

struct Box { int id; float score, x1, y1, x2, y2; };
double monotonic_now() {
    timespec stamp;
    clock_gettime(CLOCK_MONOTONIC,&stamp);
    return stamp.tv_sec+stamp.tv_nsec/1e9;
}
float overlap(const Box& a, const Box& b) {
    float intersection = std::max(0.f, std::min(a.x2,b.x2)-std::max(a.x1,b.x1)) *
                         std::max(0.f, std::min(a.y2,b.y2)-std::max(a.y1,b.y1));
    return intersection / std::max(1e-9f, (a.x2-a.x1)*(a.y2-a.y1) +
                                  (b.x2-b.x1)*(b.y2-b.y1)-intersection);
}
int main(int argc, char** argv) {
    if (argc != 6 && argc != 8) { std::cerr << "MODEL_DIR SIZE THREADS CONF IOU [DIAGNOSTIC_FRAMES TOP_K]\n"; return 2; }
    const int size = std::stoi(argv[2]), threads = std::stoi(argv[3]);
    const float conf = std::stof(argv[4]), iou = std::stof(argv[5]);
    int diagnostic_frames = argc==8 ? std::stoi(argv[6]) : 0;
    const int top_k = argc==8 ? std::stoi(argv[7]) : 10;
    if (diagnostic_frames<0 || diagnostic_frames>20 || top_k<1 || top_k>20) return 2;
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
            int expected_width=0, expected_height=0;
            double deadline=0;
            if (request.peek()=='[') {
                char open,c1,c2,c3,close;
                if (!(request >> open >> std::quoted(path) >> c1 >> expected_width >> c2
                      >> expected_height >> c3 >> deadline >> close) || open!='[' || close!=']'
                      || c1!=',' || c2!=',' || c3!=',' || expected_width<=0 || expected_height<=0
                      || expected_width>8192 || expected_height>8192 || !std::isfinite(deadline) || deadline<=0)
                    throw std::runtime_error("invalid JPEG geometry/deadline request");
            } else if (!(request >> std::quoted(path))) {
                throw std::runtime_error("invalid legacy image request");
            }
            if (path.empty() || path[0] != '/')
                throw std::runtime_error("invalid image path");
            const auto request_start = std::chrono::steady_clock::now();
            const bool diagnostic = diagnostic_frames>0;
            if (diagnostic) --diagnostic_frames;
            cv::Mat image = cv::imread(path, cv::IMREAD_COLOR);
            if (image.empty()) throw std::runtime_error("image decode failed");
            if (expected_width && (image.cols!=expected_width || image.rows!=expected_height))
                throw std::runtime_error("JPEG geometry differs from atomic frame metadata");
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
            const auto preprocess_end = std::chrono::steady_clock::now();
            if (deadline && monotonic_now()>=deadline)
                throw std::runtime_error("STALE_INPUT");
            if (extractor.input("in0",input) || extractor.extract("out0",out))
                throw std::runtime_error("NCNN extraction failed");
            const auto forward_end = std::chrono::steady_clock::now();
            if (out.dims != 2 || (out.h != 84 && out.w != 84))
                throw std::runtime_error("expected decoded 84xN or Nx84 output");
            bool rows = out.w == 84;
            int count = rows ? out.h : out.w;
            auto value = [&](int anchor, int field) -> float {
                return rows ? out.row(anchor)[field] : out.row(field)[anchor];
            };
            std::vector<Box> boxes;
            std::vector<Box> raw_top;
            const int target_ids[4]={2,39,47,49};
            std::vector<Box> target_top[4];
            std::vector<float> class_maxima(diagnostic ? 80 : 0,0.f);
            for (int n=0; n<count; n++) {
                float score=0; int id=-1;
                for (int c=0;c<80;c++) {
                    float p=value(n,c+4);
                    if (!std::isfinite(p)) throw std::runtime_error("nonfinite class output");
                    if (diagnostic) class_maxima[c]=std::max(class_maxima[c],p);
                    if (p>score) { score=p; id=c; }
                }
                if (!diagnostic && score < conf) continue;
                if (id<0) continue; // All-zero anchor has no class to diagnose.
                float x=value(n,0),y=value(n,1),w=value(n,2),h=value(n,3);
                if (!std::isfinite(x+y+w+h)) throw std::runtime_error("nonfinite box output");
                Box b{id,score,std::max(0.f,(x-w/2-left)/scale),std::max(0.f,(y-h/2-top)/scale),
                      std::min(float(image.cols),(x+w/2-left)/scale),
                      std::min(float(image.rows),(y+h/2-top)/scale)};
                if (b.x2>b.x1 && b.y2>b.y1) {
                    if (diagnostic) {
                        raw_top.push_back(b);
                        std::sort(raw_top.begin(),raw_top.end(),[](const Box& a,const Box& b){return a.score>b.score;});
                        if (int(raw_top.size())>top_k) raw_top.pop_back();
                        for(int t=0;t<4;++t) {
                            Box target=b;target.id=target_ids[t];target.score=value(n,target_ids[t]+4);
                            auto& candidates=target_top[t];
                            candidates.push_back(target);
                            std::sort(candidates.begin(),candidates.end(),[](const Box& a,const Box& b){return a.score>b.score;});
                            if(int(candidates.size())>top_k) candidates.pop_back();
                        }
                    }
                    if (score>=conf) boxes.push_back(b);
                }
            }
            std::sort(boxes.begin(), boxes.end(), [](const Box& a,const Box& b){return a.score>b.score;});
            std::vector<Box> kept;
            for (const auto& b:boxes) {
                bool suppress=false;
                for (const auto& a:kept) if(a.id==b.id && overlap(a,b)>iou) {suppress=true;break;}
                if (!suppress) kept.push_back(b);
            }
            const auto postprocess_end = std::chrono::steady_clock::now();
            auto ms = [](auto a, auto b){return std::chrono::duration<double,std::milli>(b-a).count();};
            std::cout << std::setprecision(8) << "{\"inference_ms\":" << ms(start,postprocess_end)
                      << ",\"timings_ms\":{\"decode\":" << ms(request_start,start)
                      << ",\"preprocess\":" << ms(start,preprocess_end)
                      << ",\"forward\":" << ms(preprocess_end,forward_end)
                      << ",\"postprocess\":" << ms(forward_end,postprocess_end)
                      << ",\"total\":" << ms(request_start,postprocess_end)
                      << "},\"detections\":[";
            bool first=true;
            for (const auto& b:kept) {
                if(!first) std::cout << ',';
                first=false;
                std::cout << '[' << b.id << ',' << b.score << ',' << b.x1 << ',' << b.y1 << ',' << b.x2 << ',' << b.y2 << ']';
            }
            std::cout << ']';
            if (diagnostic) {
                auto emit = [&](const std::vector<Box>& values) {
                    std::cout << '[';
                    for (int k=0;k<std::min(top_k,int(values.size()));++k) {
                        if(k) std::cout << ',';
                        const auto& b=values[k];
                        std::cout << '[' << b.id << ',' << b.score << ',' << b.x1 << ',' << b.y1 << ',' << b.x2 << ',' << b.y2 << ']';
                    }
                    std::cout << ']';
                };
                uint64_t rgb_hash=14695981039346656037ull;
                uint64_t channel_sums[3]={0,0,0};
                for(int y=0;y<padded.rows;++y) for(int x=0;x<padded.cols;++x) {
                    const auto p=padded.at<cv::Vec3b>(y,x);
                    for(int c=0;c<3;++c) {
                        unsigned char value=p[2-c];
                        rgb_hash=(rgb_hash^value)*1099511628211ull;
                        channel_sums[c]+=value;
                    }
                }
                std::cout << ",\"diagnostic\":{\"top_k\":" << top_k << ",\"conf\":" << conf << ",\"iou\":" << iou
                          << ",\"input_size\":" << size << ",\"source_size\":[" << image.cols << ',' << image.rows
                          << "],\"resized\":[" << nw << ',' << nh << "],\"padding_ltrb\":[" << left << ',' << top << ',' << size-nw-left << ',' << size-nh-top
                          << "],\"scale\":" << scale << ",\"pixel_order\":\"RGB\",\"normalization\":\"1/255 FP32\""
                          << ",\"padded_rgb_fnv1a64\":\"" << std::hex << rgb_hash << std::dec
                          << "\",\"padded_rgb_channel_sums\":[" << channel_sums[0] << ',' << channel_sums[1] << ',' << channel_sums[2]
                          << "],\"output_shape_wh\":[" << out.w << ',' << out.h << "],\"anchors\":" << count
                          << ",\"pre_nms_count\":" << boxes.size() << ",\"post_nms_count\":" << kept.size()
                          << ",\"class_maxima\":[";
                for(int c=0;c<80;++c) {if(c)std::cout << ',';std::cout << class_maxima[c];}
                std::cout << "],\"raw_top\":";emit(raw_top);
                std::cout << ",\"target_class_top\":[";
                for(int t=0;t<4;++t) {if(t)std::cout<<',';emit(target_top[t]);}
                std::cout << ']';
                std::cout << ",\"pre_nms_top\":";emit(boxes);
                std::cout << ",\"post_nms_top\":";emit(kept);
                std::cout << '}';
            }
            std::cout << '}' << std::endl;
        } catch(const std::exception& error) {
            std::cerr << "NCNN_ERROR " << error.what() << '\n';
            std::cout << "{\"error\":\"native inference failed; see bridge diagnostics\",\"error_code\":\""
                      << (std::string(error.what())=="STALE_INPUT" ? "STALE_INPUT" : "MODEL_ERROR")
                      << "\"}" << std::endl;
        }
    }
}
