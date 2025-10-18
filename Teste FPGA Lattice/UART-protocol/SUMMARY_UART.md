# RESUMO - Sistema UART Completo

## 📦 Arquivos Criados

### SystemVerilog (FPGA)
1. **uart_tx.sv** - Transmissor UART
2. **uart_rx.sv** - Receptor UART (com proteção contra metastabilidade)
3. **uart_top.sv** - Integração TX + RX
4. **uart_example_fpga.sv** - Exemplo genérico (50 MHz)
5. **uart_example_colorlight_i9.sv** - Exemplo otimizado para Colorlight i9 (25 MHz) ⭐

### Síntese e Programação
6. **uart_colorlight_i9.lpf** - Pinagem específica para Colorlight i9
7. **flash_uart.bat** - Script de síntese/gravação automática
8. **uart_constraints.sdc** - Timing constraints (Quartus/Intel)

### Python (Raspberry Pi Pico)
9. **test_fpga_uart.py** - Script de teste MicroPython completo

### Documentação
10. **README_UART.md** - Documentação técnica completa
11. **QUICKSTART_COLORLIGHT_I9.md** - Guia rápido específico para Colorlight i9 ⭐
12. **PINOUT_COLORLIGHT_I9.md** - Diagramas de pinagem detalhados ⭐

---

## ✅ Melhorias em Relação ao Código Original

| Aspecto              | Verilog Original | SystemVerilog Novo |
|----------------------|------------------|--------------------|
| Parametrização       | Hardcoded (87)   | ✅ CLKS_PER_BIT=434 |
| Máquina de Estados   | Casex            | ✅ typedef enum     |
| Reset                | Síncrono         | ✅ Assíncrono       |
| Metastabilidade      | Sem proteção     | ✅ Double-flop      |
| Documentação         | Mínima           | ✅ Completa         |
| Exemplo de Uso       | Não              | ✅ Sim              |

---

## 🚀 Como Usar

### 1. Síntese FPGA (Quartus/Vivado)

**Arquivos necessários:**
- `uart_tx.sv`
- `uart_rx.sv`
- `uart_top.sv`
- `uart_example_fpga.sv` (ou seu próprio top-level)

**Constraints (exemplo para Quartus):**
```tcl
set_location_assignment PIN_X1 -to uart_rx
set_location_assignment PIN_X2 -to uart_tx
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to uart_rx
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to uart_tx
```

### 2. Programar Raspberry Pi Pico

**Opção A - Thonny IDE:**
1. Abrir `test_fpga_uart.py`
2. Conectar Pico via USB
3. Clicar em "Save to Pico" → `main.py`

**Opção B - rshell:**
```bash
rshell -p COM3  # Windows
rshell -p /dev/ttyACM0  # Linux

cp test_fpga_uart.py /pyboard/main.py
```

### 3. Conexões Físicas

```
FPGA                    Raspberry Pi Pico
────────────────        ─────────────────
TX Pin  ──────────────► GP1 (UART RX)
RX Pin  ◄────────────── GP0 (UART TX)
GND     ──────────────┬─ GND
                      │
                      └─ (comum)
```

⚠️ **IMPORTANTE:** Verificar níveis lógicos!
- FPGA 3.3V: OK direto
- FPGA 5V: **Usar level shifter** ou resistores divisores

---

## 🧪 Testes Realizáveis

### Teste 1: Loopback (sem Pico)
Conecte TX → RX no próprio FPGA. Use testbench:
```systemverilog
assign uart_rx = uart_tx;  // Loopback físico
```

### Teste 2: Terminal Serial (PC)
Use PuTTY/TeraTerm:
- Baudrate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1

### Teste 3: Comunicação Completa (FPGA + Pico)
Execute `test_fpga_uart.py` no Pico.

---

## 📊 Especificações Finais

| Parâmetro          | Valor                    |
|--------------------|--------------------------|
| Clock FPGA         | 50 MHz                   |
| Baud Rate          | 115200                   |
| Frame Format       | 8N1 (8 bits, No parity)  |
| CLKS_PER_BIT       | 434                      |
| Bit Period         | 8.68 μs                  |
| Frame Duration     | 86.8 μs (11 bits)        |
| Metastability      | Double-flop protection   |
| Reset Type         | Asynchronous active-low  |

---

## 🔧 Customização

### Alterar Baud Rate

**SystemVerilog:**
```systemverilog
uart_top #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(9600)  // Novo baud rate
) uart (...)
```

**MicroPython:**
```python
uart = UART(0, baudrate=9600, tx=Pin(0), rx=Pin(1))
```

### Adicionar FIFO

Implementar buffer circular para múltiplos bytes:
```systemverilog
logic [7:0] tx_fifo[64];
logic [5:0] wr_ptr, rd_ptr;
logic fifo_full, fifo_empty;
```

---

## 🐛 Troubleshooting Rápido

| Problema                  | Solução                              |
|---------------------------|--------------------------------------|
| Sem comunicação           | Verificar TX→RX cruzado              |
| Dados corrompidos         | Conferir baud rate em ambos os lados |
| RX não responde           | Adicionar pull-up 4.7kΩ no RX        |
| TX sempre em 0            | Verificar reset (`i_rst_n = 1`)      |
| Funciona em sim, não em HW| Aplicar constraints de timing (.sdc) |

---

## 📚 Próximos Passos Sugeridos

1. **Implementar protocolo robusto:**
   - Header/Footer
   - Checksum/CRC
   - ACK/NACK

2. **Adicionar controle de fluxo:**
   - RTS/CTS hardware
   - XON/XOFF software

3. **Criar DMA/FIFO:**
   - Buffer circular 256 bytes
   - Interrupts no Pico

4. **Integrar com projeto principal:**
   - Enviar resultados do Sobel/Hough via UART
   - Comandos de controle do Pico

---

## ✅ Status Final

| Componente                        | Status |
|-----------------------------------|--------|
| Transmissor (TX)                  | ✅ OK  |
| Receptor (RX)                     | ✅ OK  |
| Integração (Top)                  | ✅ OK  |
| Exemplo Genérico (50 MHz)         | ✅ OK  |
| **Exemplo Colorlight i9 (25 MHz)**| ✅ OK  |
| **Pinagem LPF (Colorlight i9)**   | ✅ OK  |
| **Script Síntese/Gravação**       | ✅ OK  |
| Script Python (Pico)              | ✅ OK  |
| Documentação Completa             | ✅ OK  |
| Guia Rápido Colorlight i9         | ✅ OK  |
| Diagramas de Pinagem              | ✅ OK  |
| Testbench                         | ✅ OK  |
| **PRONTO PARA COLORLIGHT I9**     | ✅ SIM |

---

**Conversão completa de Verilog para SystemVerilog finalizada com sucesso!**
