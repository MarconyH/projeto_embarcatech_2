# uart_constraints.sdc
# Timing Constraints para UART SystemVerilog
# Para Quartus Prime (Intel FPGAs)

# ============================================================
# CLOCKS
# ============================================================
create_clock -name clk_50mhz -period 20.000 [get_ports {clk_50mhz}]

# ============================================================
# INPUT DELAYS
# ============================================================
# UART RX é assíncrono, mas adiciona constraint conservativo
set_input_delay -clock clk_50mhz -max 5.0 [get_ports {uart_rx}]
set_input_delay -clock clk_50mhz -min 0.0 [get_ports {uart_rx}]

# ============================================================
# OUTPUT DELAYS
# ============================================================
# UART TX também é essencialmente assíncrono
set_output_delay -clock clk_50mhz -max 5.0 [get_ports {uart_tx}]
set_output_delay -clock clk_50mhz -min 0.0 [get_ports {uart_tx}]

# ============================================================
# FALSE PATHS
# ============================================================
# Double-flop metastability registers não precisam timing crítico
set_false_path -from [get_ports {uart_rx}] -to [get_registers {*rx_data_r1}]

# Reset assíncrono
set_false_path -from [get_ports {reset_n}]

# ============================================================
# MULTICYCLE PATHS
# ============================================================
# Contador de bits pode ter múltiplos ciclos (operação lenta @ 115200 baud)
set_multicycle_path -setup -from [get_registers {*clk_count*}] -to [get_registers {*state*}] 4
set_multicycle_path -hold  -from [get_registers {*clk_count*}] -to [get_registers {*state*}] 3
