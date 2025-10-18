# UART SystemVerilog - Comunicação FPGA ↔ Raspberry Pi Pico

## 📋 Visão Geral

Este módulo implementa comunicação UART bidirecional entre um FPGA e um Raspberry Pi Pico em SystemVerilog moderno. Otimizado para 115200 baud @ 50 MHz.

### Arquivos Criados
- **uart_tx.sv** - Transmissor UART (FPGA → Pico)
- **uart_rx.sv** - Receptor UART (FPGA ← Pico)
- **uart_top.sv** - Módulo de integração completo

---

## ⚙️ Especificações Técnicas

| Parâmetro           | Valor              |
|---------------------|--------------------|
| Clock FPGA          | 50 MHz             |
| Baud Rate           | 115200             |
| Bits de Dados       | 8                  |
| Paridade            | Nenhuma (N)        |
| Stop Bits           | 1                  |
| CLKS_PER_BIT        | 434 (50M/115200)   |
| Nível Lógico        | 3.3V (TTL)         |

---

## 🔌 Pinagem e Conexões

### Conexão FPGA ↔ Raspberry Pi Pico

```
┌─────────────────┐           ┌──────────────────────┐
│      FPGA       │           │   Raspberry Pi Pico  │
│                 │           │                      │
│  TX (output) ───┼──────────►│  RX (GP1 ou GP5)    │
│  RX (input)  ◄──┼───────────│  TX (GP0 ou GP4)    │
│  GND         ───┼───────────│  GND                │
└─────────────────┘           └──────────────────────┘
```

### Configuração Sugerida - Pico (MicroPython/C SDK)

**MicroPython:**
```python
from machine import UART, Pin

uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
uart.init(bits=8, parity=None, stop=1)

# Enviar byte para FPGA
uart.write(b'\x42')  # Envia 0x42

# Receber byte do FPGA
if uart.any():
    data = uart.read(1)
    print(f"Recebido: {data[0]:02X}")
```

**C SDK:**
```c
#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_TX_PIN 0
#define UART_RX_PIN 1

void setup_uart() {
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
}

void uart_send(uint8_t data) {
    uart_putc_raw(UART_ID, data);
}

uint8_t uart_receive() {
    return uart_getc(UART_ID);
}
```

---

## 🧩 Uso dos Módulos SystemVerilog

### 1. Instanciação do Módulo Top-Level

```systemverilog
uart_top #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(115200)
) uart_interface (
    .i_clk       (clk_50mhz),
    .i_rst_n     (reset_n),
    .i_uart_rx   (pico_tx_pin),     // Conectar ao TX do Pico
    .o_uart_tx   (pico_rx_pin),     // Conectar ao RX do Pico
    
    // Transmissão
    .i_tx_dv     (send_enable),
    .i_tx_byte   (data_to_send),
    .o_tx_active (tx_busy),
    .o_tx_done   (tx_complete),
    
    // Recepção
    .o_rx_dv     (data_received),
    .o_rx_byte   (received_data)
);
```

### 2. Exemplo de Lógica de Transmissão

```systemverilog
logic [7:0] tx_data;
logic tx_start;

always_ff @(posedge clk_50mhz or negedge reset_n) begin
    if (!reset_n) begin
        tx_start <= 1'b0;
        tx_data  <= 8'h00;
    end else begin
        // Envia byte quando botão pressionado
        if (button_pressed && !tx_busy) begin
            tx_data  <= 8'h55;  // Envia 0x55
            tx_start <= 1'b1;
        end else begin
            tx_start <= 1'b0;
        end
    end
end

// Conectar à interface UART
assign i_tx_dv   = tx_start;
assign i_tx_byte = tx_data;
```

### 3. Exemplo de Lógica de Recepção

```systemverilog
logic [7:0] last_received;

always_ff @(posedge clk_50mhz or negedge reset_n) begin
    if (!reset_n) begin
        last_received <= 8'h00;
    end else begin
        // Captura byte quando disponível
        if (data_received) begin
            last_received <= received_data;
            
            // Lógica de resposta (echo)
            case (received_data)
                8'h01: begin
                    // Responde ao comando 0x01
                    // ... implementar resposta
                end
                8'h02: begin
                    // Responde ao comando 0x02
                    // ... implementar resposta
                end
                default: begin
                    // Comando desconhecido
                end
            endcase
        end
    end
end
```

---

## 🎯 Protocolo de Comunicação Sugerido

### Estrutura de Pacote Simples

```
┌─────────┬──────────┬──────────┬─────────────┬──────────┐
│ HEADER  │ COMMAND  │  LENGTH  │    DATA     │ CHECKSUM │
│ (0xAA)  │ (1 byte) │ (1 byte) │ (N bytes)   │ (1 byte) │
└─────────┴──────────┴──────────┴─────────────┴──────────┘
```

**Exemplo de implementação:**

```systemverilog
typedef enum logic [7:0] {
    CMD_READ_STATUS  = 8'h10,
    CMD_WRITE_DATA   = 8'h20,
    CMD_START_PROC   = 8'h30,
    CMD_STOP_PROC    = 8'h31,
    CMD_RESET        = 8'hFF
} command_t;

logic [7:0] packet_buffer[16];
logic [3:0] buffer_idx;

always_ff @(posedge clk_50mhz or negedge reset_n) begin
    if (!reset_n) begin
        buffer_idx <= '0;
    end else if (data_received) begin
        if (received_data == 8'hAA) begin
            // Início de pacote
            buffer_idx <= '0;
            packet_buffer[0] <= 8'hAA;
        end else if (buffer_idx > 0) begin
            // Recebe restante do pacote
            packet_buffer[buffer_idx] <= received_data;
            buffer_idx <= buffer_idx + 1'b1;
            
            // Processa quando pacote completo
            if (buffer_idx == packet_buffer[2] + 3) begin
                process_packet();
                buffer_idx <= '0;
            end
        end
    end
end
```

---

## 📊 Diagrama de Temporização UART

```
Idle   Start  D0  D1  D2  D3  D4  D5  D6  D7  Stop  Idle
 1      0     X   X   X   X   X   X   X   X    1     1
───┐   ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐       ┌───
   └───┘   └───┴───┴───┴───┴───┴───┴───┴───┘───────┘

|<-- 434 clocks @ 50MHz -->|  (8.68 μs por bit)
```

**Timing @ 115200 baud:**
- Bit period: 8.68 μs
- Start bit: 8.68 μs
- 8 data bits: 69.44 μs
- Stop bit: 8.68 μs
- **Total frame:** 86.8 μs (11 bits)

---

## 🧪 Testbench de Validação

```systemverilog
module uart_top_tb;
    logic clk, rst_n;
    logic uart_loopback;  // TX → RX loopback
    logic tx_dv;
    logic [7:0] tx_byte, rx_byte;
    logic tx_done, rx_dv;

    // Clock 50 MHz
    always #10ns clk = ~clk;

    uart_top #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE(115200)
    ) dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_uart_rx(uart_loopback),
        .o_uart_tx(uart_loopback),  // Loopback test
        .i_tx_dv(tx_dv),
        .i_tx_byte(tx_byte),
        .o_tx_done(tx_done),
        .o_rx_dv(rx_dv),
        .o_rx_byte(rx_byte)
    );

    initial begin
        clk = 0; rst_n = 0; tx_dv = 0;
        #100ns rst_n = 1;
        
        // Teste: Enviar 0xA5
        @(posedge clk);
        tx_byte = 8'hA5;
        tx_dv = 1;
        @(posedge clk);
        tx_dv = 0;
        
        // Aguarda recepção
        @(posedge rx_dv);
        assert(rx_byte == 8'hA5) else $error("Falha no loopback!");
        
        $display("Teste UART OK!");
        $finish;
    end
endmodule
```

---

## 🔍 Troubleshooting

### Problema: Dados corrompidos na recepção

**Causas possíveis:**
1. **Baud rate incorreto** - Verificar CLKS_PER_BIT
2. **Clock instável** - Usar PLL para gerar 50 MHz estável
3. **Ruído na linha** - Adicionar resistor pull-up de 4.7kΩ no RX

**Solução:**
```systemverilog
// Adicionar filtro de ruído (debounce) no RX
logic [3:0] rx_filter;
logic rx_filtered;

always_ff @(posedge i_clk) begin
    rx_filter <= {rx_filter[2:0], i_uart_rx};
    if (&rx_filter) rx_filtered <= 1'b1;
    else if (~|rx_filter) rx_filtered <= 1'b0;
end
```

### Problema: TX não envia dados

**Verificações:**
1. Reset está sendo aplicado corretamente? (`i_rst_n = 1` em operação)
2. `i_tx_dv` está gerando pulso de 1 ciclo?
3. Clock 50 MHz está presente?

### Problema: Comunicação funciona em simulação mas não em hardware

**Checklist:**
- [ ] Pinos TX/RX conectados corretamente (TX FPGA → RX Pico)
- [ ] GND compartilhado entre FPGA e Pico
- [ ] Níveis de tensão compatíveis (ambos 3.3V)
- [ ] Restrições de timing aplicadas (.sdc)
- [ ] Baud rate configurado igual em ambos os lados

---

## 📈 Otimizações Futuras

### 1. FIFO para Buffering
```systemverilog
// TX FIFO para múltiplos bytes
logic [7:0] tx_fifo[16];
logic [3:0] tx_wr_ptr, tx_rd_ptr;

// Permite enfileirar bytes sem esperar TX terminar
```

### 2. Controle de Fluxo (RTS/CTS)
```systemverilog
// Hardware flow control
input  logic i_cts_n,  // Clear To Send (do Pico)
output logic o_rts_n   // Request To Send (do FPGA)
```

### 3. Detecção de Erros
```systemverilog
// Frame error, overrun error
output logic o_frame_error,
output logic o_overrun_error
```

---

## 📚 Referências

- **Raspberry Pi Pico Datasheet:** [https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf)
- **UART Protocol Specification:** [https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
- **SystemVerilog IEEE 1800-2017:** [https://ieeexplore.ieee.org/document/8299595](https://ieeexplore.ieee.org/document/8299595)

---

## ✅ Status do Projeto

| Item                          | Status |
|-------------------------------|--------|
| Transmissor (uart_tx.sv)      | ✅ OK  |
| Receptor (uart_rx.sv)         | ✅ OK  |
| Integração (uart_top.sv)      | ✅ OK  |
| Testbench                     | ✅ OK  |
| Documentação                  | ✅ OK  |
| Teste em Hardware             | ⏳ Pendente |

---

**Última atualização:** Conversão completa de Verilog para SystemVerilog  
**Autor:** Projeto Embarcatech - Etapa 2  
**Licença:** MIT
