"""Exact, reviewable private CSI changes; never writes the archived inputs."""
import hashlib
from pathlib import Path

ROOT = Path('repo/mipi/mipi_csi_rx_4lane/src/mipi-csi-rx')
HERE = Path(__file__).resolve().parent


def digest(data):
    return hashlib.sha256(data).hexdigest()


def patch_source(source):
    changes = []
    def edit(name, replacements, append=''):
        path = source / ROOT / name
        before = path.read_bytes()
        text = before.decode('utf-8').replace('\r\n', '\n')
        for old, new in replacements:
            if text.count(old) != 1:
                raise ValueError('CSI exact patch context not unique: ' + name + ': ' + old)
            text = text.replace(old, new)
        after = (text + append).encode('utf-8')
        path.write_bytes(after)
        changes.append(dict(path=(ROOT / name).as_posix(), original_sha256=digest(before),
                            patched_sha256=digest(after)))
    edit('csi_4lane_raw10.v', [
        ('\tinput                reset,', '''\tinput                reset,
    input                delay_refclock,
    input                delay_reset,
    input                io_reset,
    input                all_ready,
    output               delay_ready,'''),
        ('.ref_clock_in(ref_clock_in),', '''.ref_clock_in(ref_clock_in),
    .delay_refclock(delay_refclock),
    .delay_reset(delay_reset),
    .io_reset(io_reset),
    .all_ready(all_ready),
    .delay_ready(delay_ready),''')])
    edit('csi_rx_top.vhd', [
        ('    byte_clock_out : out std_logic;', '''    delay_refclock : in std_logic; -- private compliant IDELAY reference
    delay_reset : in std_logic; -- lock-qualified >=52ns reference reset
    io_reset : in std_logic;
    all_ready : in std_logic;
    delay_ready : out std_logic;
    byte_clock_out : out std_logic;'''),
        ('      ref_clock => ref_clock_in,', '''      ref_clock => ref_clock_in,
      delay_refclock => delay_refclock,
      delay_reset => delay_reset,
      io_reset => io_reset,
      all_ready => all_ready,
      delay_ready => delay_ready,''')])
    edit('csi_rx_4_lane_link.vhd', [
        ('    reset : in STD_LOGIC;', '''    delay_refclock : in std_logic;
    delay_reset : in std_logic;
    io_reset : in std_logic;
    all_ready : in std_logic;
    delay_ready : out std_logic;
    reset : in STD_LOGIC;'''),
        ('  signal rdy : std_logic ;', '''  signal rdy : std_logic;
  signal serdes_reset_det : std_logic;
  signal ready_byte : std_logic_vector(1 downto 0) := "00";
  signal ready_count : unsigned(6 downto 0) := (others => '0');
  signal application_ready : std_logic := '0';
  signal word_valid_int : std_logic;
  signal phy_reset : std_logic;
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ready_byte : signal is "TRUE";
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of ready_byte : signal is "NO";'''),
        ('      reset_out => serdes_reset);', '      reset_out => serdes_reset_det);'),
        ('      valid_out => word_valid);', '      valid_out => word_valid_int);'),
        ('  gen_idctl : if generate_idelayctrl generate', '''  -- Primitive IO reset releases before IDELAYCTRL, independent of sensor clocks.
  -- Clock-loss resets are applied to the SERDES only after initial calibration.
  phy_reset <= io_reset or (serdes_reset_det and application_ready);
  delay_ready <= rdy;
  word_valid <= word_valid_int and application_ready;
  -- ALL used IDELAYCTRLs must calibrate; then wait >=64 local application cycles.
  -- The original PL0 clock detector remains on the unchanged PL0 clock.
  process(word_clock_int, reset, delay_reset, all_ready)
  begin
    if reset = '1' or delay_reset = '1' or all_ready /= '1' then
      ready_byte <= "00";
    elsif rising_edge(word_clock_int) then
      ready_byte <= ready_byte(0) & '1';
    end if;
  end process;
  process(word_clock_int, reset, all_ready)
  begin
    if reset = '1' or all_ready /= '1' then
      ready_count <= (others => '0');
      application_ready <= '0';
    elsif rising_edge(word_clock_int) then
      if ready_byte(1) = '0' then
        ready_count <= (others => '0');
        application_ready <= '0';
      elsif ready_count < 64 then
        ready_count <= ready_count + 1;
      else
        application_ready <= '1';
      end if;
    end if;
  end process;
  serdes_reset <= serdes_reset_det or not application_ready;
  gen_no_idctl : if not generate_idelayctrl generate
    rdy <= not delay_reset;
  end generate;
  gen_idctl : if generate_idelayctrl generate'''),
        ('        ref_clock => ref_clock,\n        reset => reset,',
         '        ref_clock => delay_refclock,\n        reset => delay_reset,')]
        + [('      reset => serdes_reset,\n      dphy_hs => dphy_d' + str(i),
            '      reset => phy_reset,\n      io_reset => io_reset,\n      application_ready => application_ready,\n      dphy_hs => dphy_d' + str(i)) for i in range(4)])
    edit('csi_rx_hs_lane_phy.vhd', [
        ('REFCLK_FREQUENCY => 200.0,  -- IDELAYCTRL', 'REFCLK_FREQUENCY => 301.055970,  -- IDELAYCTRL'),
        ('  reset : in STD_LOGIC;', '''  io_reset : in STD_LOGIC;
  application_ready : in STD_LOGIC;
  reset : in STD_LOGIC;'''),
        ("        RST => '0'                  -- 1-bit input: Asynchronous Reset", "        RST => io_reset             -- 1-bit input: Asynchronous Reset"),
        ('          RST => reset_lat ', '          RST => primitive_reset '),
        ('signal reset_lat : std_logic;', '''signal reset_lat : std_logic;
signal reset_sync : std_logic_vector(1 downto 0) := "11";
signal primitive_reset : std_logic;
attribute ASYNC_REG : string;
attribute ASYNC_REG of reset_sync : signal is "TRUE";
attribute SHREG_EXTRACT : string;
attribute SHREG_EXTRACT of reset_sync : signal is "NO";'''),
        ('''  process(byte_clock)
  begin
  if rising_edge(byte_clock) then
      reset_lat <= reset;
  end if;
  end process;''', '''  process(byte_clock, reset)
  begin
    if reset = '1' then
      reset_sync <= "11";
    elsif rising_edge(byte_clock) then
      reset_sync <= reset_sync(0) & '0';
    end if;
  end process;
  reset_lat <= reset_sync(1);
  primitive_reset <= io_reset or (reset_lat and application_ready);''')])
    component = source / ROOT.parent.parent / 'component.xml'
    before = component.read_bytes()
    text = before.decode('utf-8')
    ports = ''.join('''    <spirit:port><spirit:name>%s</spirit:name><spirit:wire><spirit:direction>%s</spirit:direction></spirit:wire></spirit:port>\n''' % (n, d) for n, d in
        [('delay_refclock', 'in'), ('delay_reset', 'in'), ('io_reset', 'in'),
         ('all_ready', 'in'), ('delay_ready', 'out')])
    if text.count('</spirit:ports>') != 1:
        raise ValueError('CSI component port context not unique')
    after = text.replace('</spirit:ports>', ports + '</spirit:ports>').encode('utf-8')
    component.write_bytes(after)
    changes.append(dict(path=component.relative_to(source).as_posix(),
                        original_sha256=digest(before), patched_sha256=digest(after)))
    try:
        from .structural_patch import apply_structural
    except ImportError:
        from structural_patch import apply_structural
    original = {row['path']: row['original_sha256'] for row in changes}
    for name in ['csi_rx_clock_det.vhd', 'csi_rx_hs_clk_phy.vhd']:
        original[(ROOT / name).as_posix()] = digest((source / ROOT / name).read_bytes())
    apply_structural(source)
    return [dict(path=name, original_sha256=before,
                 patched_sha256=digest((source/name).read_bytes())) for name,before in original.items()]


def verify_patches(camera, build, ledger):
    """Recompute expected bytes in memory, in a temporary private tree."""
    import tempfile
    import shutil
    with tempfile.TemporaryDirectory(prefix='ah-csi-audit-') as folder:
        source = Path(folder)
        shutil.copytree(camera / 'project' / ROOT, source / ROOT)
        shutil.copy2(camera / 'project' / ROOT.parent.parent / 'component.xml',
                     source / ROOT.parent.parent / 'component.xml')
        expected = patch_source(source)
        if expected != ledger:
            raise ValueError('CSI patch ledger differs from reviewed exact transformation')
        for row in expected:
            if digest((build / 'source' / row['path']).read_bytes()) != row['patched_sha256']:
                raise ValueError('private CSI source differs from exact patch: ' + row['path'])
    return {row['path'] for row in expected}
