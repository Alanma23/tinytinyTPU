"""
Activation Function testbench for TinyTinyTPU.
Tests ReLU activation function.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import os
import shutil


@cocotb.test()
async def test_activation_func_reset(dut):
    """Test activation_func reset behavior"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.reset.value = 1
    dut.valid_in.value = 0
    dut.data_in.value = 0

    await ClockCycles(dut.clk, 2)

    assert dut.valid_out.value == 0, "valid_out should be 0 after reset"
    assert dut.data_out.value.signed_integer == 0, "data_out should be 0 after reset"

    dut._log.info("PASS: Activation function reset test")


@cocotb.test()
async def test_activation_func_relu_positive(dut):
    """Test ReLU with positive input (should pass through)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.reset.value = 1
    await ClockCycles(dut.clk, 2)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    # Test positive value
    dut.valid_in.value = 1
    dut.data_in.value = 42
    await ClockCycles(dut.clk, 2)

    result = dut.data_out.value.signed_integer
    assert result == 42, f"ReLU(42) should be 42, got {result}"
    assert dut.valid_out.value == 1, "valid_out should be 1"

    dut._log.info("PASS: ReLU positive input test")


@cocotb.test()
async def test_activation_func_relu_negative(dut):
    """Test ReLU with negative input (should clamp to 0)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.reset.value = 1
    await ClockCycles(dut.clk, 2)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    # Test negative value (use two's complement)
    dut.valid_in.value = 1
    dut.data_in.value = (-10) & 0xFFFFFFFF  # 32-bit two's complement
    await ClockCycles(dut.clk, 2)

    result = dut.data_out.value.signed_integer
    assert result == 0, f"ReLU(-10) should be 0, got {result}"

    dut._log.info("PASS: ReLU negative input test")


@cocotb.test()
async def test_activation_func_relu_zero(dut):
    """Test ReLU with zero input"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.reset.value = 1
    await ClockCycles(dut.clk, 2)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    dut.valid_in.value = 1
    dut.data_in.value = 0
    await ClockCycles(dut.clk, 2)

    result = dut.data_out.value.signed_integer
    assert result == 0, f"ReLU(0) should be 0, got {result}"

    dut._log.info("PASS: ReLU zero input test")


def test_activation_func_runner():
    """Run activation_func tests using cocotb_tools.runner"""
    from cocotb_tools.runner import get_runner
    
    sim_dir = os.path.dirname(__file__)
    rtl_dir = os.path.join(sim_dir, "..", "..", "rtl")
    wave_dir = os.path.join(sim_dir, "..", "waves")
    build_dir = os.path.join(sim_dir, "..", "sim_build", "activation_func")
    
    os.makedirs(wave_dir, exist_ok=True)
    
    # Clean existing build to avoid conflicts
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)
    
    # Check if waveforms are requested via WAVES env var
    waves_enabled = os.environ.get("WAVES", "0") != "0"
    
    runner = get_runner("verilator")
    runner.build(
        sources=[os.path.join(rtl_dir, "activation_func.sv")],
        hdl_toplevel="activation_func",
        build_dir=build_dir,
        waves=waves_enabled,
        build_args=["--timing",
                   "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "-Wno-UNUSEDSIGNAL"]
    )
    runner.test(
        hdl_toplevel="activation_func",
        test_module="tests.test_activation_func",
        waves=waves_enabled
    )
    
    # Copy VCD to waves directory if generated
    if waves_enabled:
        vcd_src = os.path.join(build_dir, "dump.vcd")
        if os.path.exists(vcd_src):
            shutil.copy(vcd_src, os.path.join(wave_dir, "activation_func.vcd"))
            print(f"Waveform saved to {wave_dir}/activation_func.vcd")


if __name__ == "__main__":
    test_activation_func_runner()
