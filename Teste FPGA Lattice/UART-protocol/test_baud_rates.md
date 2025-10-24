# Diagnóstico de Baud Rate - UART FPGA <-> Raspberry Pi Pico

## Problema Identificado
- Pico envia: 'A' (0x41) = `01000001`
- FPGA recebe: 0x20 = `00100000`

## Análise
O bit está sendo deslocado! Isso indica erro de **timing/amostragem**.

## Possíveis Causas

### 1. Clock Real Diferente
- **LPF diz**: 25 MHz
- **Clock REAL pode ser**: 24 MHz, 27 MHz, 50 MHz?
  
### 2. Amostragem Incorreta
- START_BIT aguarda CLKS_PER_BIT/2 antes de validar
- DATA_BITS amostra em CLKS_PER_BIT/2
- Pode estar amostrando cedo/tarde demais

### 3. Solução: Testar Diferentes CLKS_PER_BIT

Para 115200 baud:
- **24 MHz**: 208 ciclos/bit
- **25 MHz**: 217 ciclos/bit  ← ATUAL
- **27 MHz**: 234 ciclos/bit
- **50 MHz**: 434 ciclos/bit

## Teste Rápido

### Opção A: Testar 9600 baud (mais tolerante)
```c
// No Raspberry Pi Pico (main.c)
#define BAUD_RATE 9600
```

```systemverilog
// No FPGA (uart_echo_colorlight_i9.sv)
uart_top #(
    .CLK_FREQ_HZ(25_000_000),
    .BAUD_RATE(9600)  // 25M/9600 = 2604 ciclos/bit
```

### Opção B: Oversampling 16x
Implementar receptor com oversampling para maior tolerância.

## Ação Imediata
Vamos testar 9600 baud primeiro para validar a lógica.
