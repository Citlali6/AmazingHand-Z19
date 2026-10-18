"""Exact v2 -> structural private-source transformation, auditable from archive."""
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = Path('repo/mipi/mipi_csi_rx_4lane/src/mipi-csi-rx')


def apply_structural(source):
    def once(text, old, new):
        if text.count(old) != 1:
            raise ValueError('structural context not unique: '+old[:70])
        return text.replace(old, new)

    def edit(name, old, new):
        p = source / ROOT / name
        text = p.read_text(encoding='utf-8')
        if text.count(old) != 1:
            raise ValueError('structural patch context not unique: '+name+': '+old[:70])
        p.write_text(text.replace(old,new),encoding='utf-8',newline='\n')
    p = source / ROOT / 'csi_rx_clock_det.vhd'
    notice = p.read_text(encoding='utf-8').split('entity csi_rx_clock_det is')[0]
    p.write_text(notice + (HERE/'csi_clock_detector.vhd').read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
    # Reset combiners formerly fed multiple domains directly. Only qualified
    # ref-domain state crosses one XPM reset, then application uses local reset.
    link = source / ROOT / 'csi_rx_4_lane_link.vhd'
    text = link.read_text(encoding='utf-8')
    start = text.index('  -- Primitive IO reset releases')
    end = text.index('  gen_no_idctl',start)
    text = text[:start] + """  -- Initial primitive IO reset remains independent of sensor clocks/RDY.
  phy_reset <= io_reset or (serdes_reset_det and application_ready);
  delay_ready <= rdy;
  word_valid <= word_valid_int and application_ready;
  qualification : entity work.csi_application_gate
    port map(byte_clk=>word_clock_int, qualified=>all_ready,
             ready=>application_ready, reset_byte=>application_reset_byte);
  serdes_reset <= serdes_reset_det or application_reset_byte or not application_ready;
""" + text[end:]
    # Mixed-language component binding is explicit, supported by Vivado.
    text = once(text, '  signal ready_byte : std_logic_vector(1 downto 0) := "00";',
        '  signal ready_byte : std_logic_vector(1 downto 0) := "00";\n  signal application_reset_byte : std_logic;')
    text = once(text, '  attribute ASYNC_REG : string;', """  component csi_application_gate is
    port(byte_clk, qualified : in std_logic; ready, reset_byte : out std_logic);
  end component;
  attribute ASYNC_REG : string;""")
    text = once(text, 'qualification : entity work.csi_application_gate','qualification : csi_application_gate')
    link.write_text(text,encoding='utf-8',newline='\n')
    edit('csi_rx_top.vhd', '    byte_clock_out : out std_logic;',
         '    rx_reset_out : out std_logic;\n    byte_clock_out : out std_logic;')
    edit('csi_rx_top.vhd', '   byte_clock_out <= csi_byte_clock;',
         '   rx_reset_out <= link_reset_out;\n   byte_clock_out <= csi_byte_clock;')
    # Remove the redundant OR-before-reset-synchronizer in every lane. Runtime
    # detector reset is already a byte-domain XPM output; calibration primitive
    # reset still releases before CTRL with no RDY or camera clock dependency.
    edit('csi_rx_hs_lane_phy.vhd',
        """  process(byte_clock, reset)
  begin
    if reset = '1' then
      reset_sync <= "11";
    elsif rising_edge(byte_clock) then
      reset_sync <= reset_sync(0) & '0';
    end if;
  end process;
  reset_lat <= reset_sync(1);
  primitive_reset <= io_reset or (reset_lat and application_ready);""",
        """  reset_lat <= reset;
  primitive_reset <= reset;""")
    # UG949 ISERDESE3 guidance: one CLK net on both pins, local inversion.
    edit('csi_rx_hs_lane_phy.vhd', "IS_CLK_B_INVERTED => '0',   -- Optional inversion for CLK_B",
         "IS_CLK_B_INVERTED => '1',   -- Local inversion; same physical CLK net")
    edit('csi_rx_hs_lane_phy.vhd', 'CLK_B => ddr_bit_clock_b,', 'CLK_B => ddr_bit_clock,')
    # BUFGCE_DIV clear release follows the undivided clock, which is available
    # independently of DIV output. No reset circularity on a stopped byte clock.
    edit('csi_rx_hs_clk_phy.vhd', 'use UNISIM.VComponents.all;',
         'use UNISIM.VComponents.all;\nlibrary xpm;\nuse xpm.vcomponents.all;')
    edit('csi_rx_hs_clk_phy.vhd', 'signal byte_clock_int : std_logic;',
         'signal byte_clock_int : std_logic;\nsignal divider_reset : std_logic;')
    edit('csi_rx_hs_clk_phy.vhd', '  gen_us: if series = "ULTRASCALE_PLUS"generate',
         """  gen_us: if series = "ULTRASCALE_PLUS"generate
    reset_divider : xpm_cdc_async_rst
      generic map(DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, RST_ACTIVE_HIGH=>1)
      port map(src_arst=>reset, dest_clk=>bit_clock_int, dest_arst=>divider_reset);""")
    edit('csi_rx_hs_clk_phy.vhd', 'CLR => reset, -- 1-bit input: Asynchronous clear',
         'CLR => divider_reset, -- synchronized to undivided clock')
    # The wrapper no longer runs uninitialized long counters or a single-flop
    # ready crossing. XPM FIFO reset and busy are actual gate inputs.
    p = source / ROOT / 'csi_4lane_raw10.v'
    text = p.read_text(encoding='utf-8')
    start = text.index('always@(posedge m_axis_video_aclk)')
    end = text.index('xpm_fifo_async #',start)
    text = text[:start] + """wire fifo_reset, wr_busy, rd_busy, wr_enable, rd_enable, output_valid;
csi_fifo_gate gate(.byte_clk(byte_clock_out),.stream_clk(m_axis_video_aclk),
  .link_reset(link_reset),.stream_reset_n(m_axis_video_aresetn),.wr_busy(wr_busy),.rd_busy(rd_busy),.full(full),.empty(empty),
  .source_valid(s_axis_tvalid),.sink_ready(m_axis_video_tready),
  .fifo_reset(fifo_reset),.wr_en(wr_enable),.rd_en(rd_enable),.out_valid(output_valid));
assign m_axis_video_tvalid = output_valid;
assign s_axis_tready = ~full & ~wr_busy;

""" + text[end:]
    replacements = {
      '.rst              (~s_axis_video_aresetn)':'.rst              (fifo_reset)',
      '.wr_en            (s_axis_tvalid & fifo_ready)':'.wr_en            (wr_enable)',
      '.rd_en            (m_axis_video_tready & ~empty & fifo_ready_maxis)':'.rd_en            (rd_enable)',
      '.wr_rst_busy      ()':'.wr_rst_busy      (wr_busy)',
      '.rd_rst_busy      ()':'.rd_rst_busy      (rd_busy)'}
    for a,b in replacements.items():
        if text.count(a)!=1: raise ValueError('FIFO exact context missing '+a)
        text=text.replace(a,b)
    text=once(text, '.byte_clock_out(byte_clock_out),', '.byte_clock_out(byte_clock_out),\n    .rx_reset_out(link_reset),')
    text = once(text, 'wire       byte_clock_out;', 'wire       byte_clock_out;\nwire       link_reset;')
    text += '\n' + (HERE/'csi_cdc_helpers.v').read_text(encoding='utf-8')
    p.write_text(text,encoding='utf-8',newline='\n')
    component = source / ROOT.parent.parent / 'component.xml'
    text=component.read_text(encoding='utf-8')
    text=once(text, '<xilinx:xpmLibrary>XPM_FIFO</xilinx:xpmLibrary>',
        '<xilinx:xpmLibrary>XPM_FIFO</xilinx:xpmLibrary>\n        <xilinx:xpmLibrary>XPM_CDC</xilinx:xpmLibrary>')
    component.write_text(text,encoding='utf-8',newline='\n')
