# Pinagem UART - Colorlight i9 v7.2

## 📌 Pinout Completo

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    Colorlight i9 v7.2 - Pinout UART                   ║
║                    LFE5U-45F-6BG381C (ECP5)                           ║
╚═══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   [P3]  Clock 25 MHz ●                    ● [E2]  UART TX         │
│                                                    (FPGA → Pico)    │
│   [D1]  Reset (BTN)  ●                    ● [D2]  UART RX         │
│                                                    (FPGA ← Pico)    │
│                                                                     │
│   ┌─────────────────────────────────────────────────────┐         │
│   │                                                       │         │
│   │         Lattice ECP5 LFE5U-45F                      │         │
│   │         FPGA Core                                    │         │
│   │                                                       │         │
│   │         25 MHz Oscillator                            │         │
│   │         45K LUTs                                     │         │
│   └─────────────────────────────────────────────────────┘         │
│                                                                     │
│   [B1]  LED 0 ●                           ● [E3]  LED RX Active   │
│   [C2]  LED 1 ●                           ● [F3]  LED TX Active   │
│   [C1]  LED 2 ●                                                    │
│   [D3]  LED 3 ●                                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
         │                                          │
         │ USB (Programação)                        │ Alimentação 5V
         └──────────────────────────────────────────┘

```

---

## 🔌 Conexões com Raspberry Pi Pico

### Diagrama de Conexão

```
┌──────────────────────────────────────────────────────────────────────┐
│                      CONEXÃO UART                                    │
└──────────────────────────────────────────────────────────────────────┘

    Colorlight i9                             Raspberry Pi Pico
    ─────────────                             ─────────────────
    
    [E2] TX ─────────────────────────────────► [GP1] RX (pino 2)
         (3.3V LVCMOS33)              
                                              
    [D2] RX ◄───────────────────────────────── [GP0] TX (pino 1)
         (3.3V LVCMOS33, Pull-Up)     
                                              
     GND ────────────────┬────────────────────  GND (pino 3, 8, 13...)
                         │                     
                         └─ Terra Comum (ESSENCIAL!)
    
    
     5V USB ─────────┐                    3.3V ◄─── Regulador interno
                     │                     5V  ◄─── USB (pino 40)
              Alimentação                   
              Separada                    ⚠️ NÃO conectar VCC entre eles!

```

---

## 📋 Tabela de Pinos Detalhada

### Sinais UART

| Função    | Pino i9 | Tipo        | Direção         | Pino Pico | Configuração      |
|-----------|---------|-------------|-----------------|-----------|-------------------|
| Clock     | P3      | Input       | -               | -         | 25 MHz            |
| Reset     | D1      | Input       | Botão           | -         | Pull-Up           |
| **TX**    | **E2**  | **Output**  | **FPGA→Pico**  | **GP1**   | LVCMOS33, 8mA     |
| **RX**    | **D2**  | **Input**   | **FPGA←Pico**  | **GP0**   | LVCMOS33, Pull-Up |

### LEDs de Status

| LED           | Pino i9 | Função                              | Ativo       |
|---------------|---------|-------------------------------------|-------------|
| LED 0         | B1      | Controlado via UART (bit 0)         | Alto        |
| LED 1         | C2      | Controlado via UART (bit 1)         | Alto        |
| LED 2         | C1      | Controlado via UART (bit 2)         | Alto        |
| LED 3         | D3      | Controlado via UART (bit 3)         | Alto        |
| RX Active     | E3      | Pisca ao receber dados              | Alto        |
| TX Active     | F3      | Pisca ao transmitir dados           | Alto        |

---

## 🎨 Pinagem do Raspberry Pi Pico

```
                Raspberry Pi Pico (Pinout)
                
     ┌─────────────────────────────────┐
     │  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  │  USB
     │  1  2  3  4  5  6  7  8  9  10 │  
     │                                 │  ┌───┐
     │ GP0 GP1 GND                     │  │   │
     │  │   │   │                      │  └───┘
     │  │   │   └───────────────────┐  │
     │  │   └───────────────┐       │  │
     │  └───────┐           │       │  │
     │          │           │       │  │
     │         20  21  22  23  24  25 │
     │  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  │
     └─────────────────────────────────┘
     
     Pinos usados:
     ──────────────────────────────────
     GP0 (pino 1)  → UART TX (→ FPGA RX/D2)
     GP1 (pino 2)  → UART RX (← FPGA TX/E2)
     GND (pino 3)  → GND comum com FPGA
```

---

## ⚡ Características Elétricas

### Níveis Lógicos

| Parâmetro          | Colorlight i9 | Raspberry Pi Pico | Compatível? |
|--------------------|---------------|-------------------|-------------|
| VCC                | 3.3V          | 3.3V              | ✅ SIM      |
| V_IH (High Input)  | 2.0V          | 2.0V              | ✅ SIM      |
| V_IL (Low Input)   | 0.8V          | 0.8V              | ✅ SIM      |
| V_OH (High Output) | 3.0V min      | 3.0V min          | ✅ SIM      |
| V_OL (Low Output)  | 0.4V max      | 0.4V max          | ✅ SIM      |
| Drive Strength     | 8 mA          | 12 mA             | ✅ SIM      |

**✅ Conexão direta OK - Ambos operam em 3.3V CMOS**

---

## 🔧 Configuração LPF (uart_colorlight_i9.lpf)

```lpf
# Clock
LOCATE COMP "clk_50mhz" SITE "P3";
IOBUF  PORT "clk_50mhz" IO_TYPE=LVCMOS33;
FREQUENCY PORT "clk_50mhz" 25.0 MHz;

# Reset
LOCATE COMP "reset_n" SITE "D1";
IOBUF  PORT "reset_n" IO_TYPE=LVCMOS33 PULLMODE=UP;

# UART
LOCATE COMP "uart_tx" SITE "E2";
IOBUF  PORT "uart_tx" IO_TYPE=LVCMOS33 DRIVE=8 SLEWRATE=FAST;

LOCATE COMP "uart_rx" SITE "D2";
IOBUF  PORT "uart_rx" IO_TYPE=LVCMOS33 PULLMODE=UP;

# LEDs (4 LEDs controláveis)
LOCATE COMP "leds[0]" SITE "B1";
LOCATE COMP "leds[1]" SITE "C2";
LOCATE COMP "leds[2]" SITE "C1";
LOCATE COMP "leds[3]" SITE "D3";

# LEDs de status UART
LOCATE COMP "led_rx_active" SITE "E3";
LOCATE COMP "led_tx_active" SITE "F3";
```

---

## 🧪 Teste de Continuidade

Antes de conectar, verifique com multímetro:

```
1. ✅ GND Colorlight i9 ←→ GND Raspberry Pi Pico
   (Deve ter continuidade ~0Ω)

2. ✅ TX i9 (E2) ←→ RX Pico (GP1)
   (Jumper intacto)

3. ✅ RX i9 (D2) ←→ TX Pico (GP0)
   (Jumper intacto)

4. ⚠️ VCC Colorlight ←→ VCC Pico
   (NÃO deve ter continuidade - alimentação separada!)
```

---

## 📊 Timing Budget

| Parâmetro             | Valor                  |
|-----------------------|------------------------|
| Clock FPGA            | 25 MHz (40 ns período) |
| Baud Rate             | 115200 bps             |
| Bit Period            | 8.68 μs                |
| Clocks por Bit        | 217 (8680 ns / 40 ns)  |
| Frame Time (11 bits)  | 95.5 μs                |
| Latência RX           | ~0.5 ms (pior caso)    |

**Margem:** >200 clocks por bit → Timing robusto ✅

---

## 🎯 Teste de Funcionalidade

### Verificação Visual

Após gravar e executar `test_fpga_uart.py`:

| LED           | Estado Esperado                         |
|---------------|-----------------------------------------|
| LED 0 (B1)    | Segue comandos 0x01, 0x02, 0x03, 0x04   |
| LED 1 (C2)    | Segue comandos 0x02, 0x03, 0x04         |
| LED 2 (C1)    | Segue comandos 0x03, 0x04               |
| LED 3 (D3)    | Segue comando 0x04                      |
| RX LED (E3)   | **Pisca** a cada comando recebido       |
| TX LED (F3)   | **Pisca** a cada resposta enviada (0xAA)|

### Teste com Osciloscópio (opcional)

```
Canal 1: FPGA TX (E2)
  - Idle: 3.3V
  - Start bit: 0V por 8.68 μs
  - Data: 8 bits (LSB primeiro)
  - Stop bit: 3.3V por 8.68 μs

Canal 2: FPGA RX (D2)
  - Formato idêntico
  - Triggered on falling edge
```

---

## 🐛 Solução de Problemas Comuns

### LED RX/TX não piscam

**Causa:** FPGA não gravado ou reset não liberado

**Solução:**
```powershell
# Regravar FPGA
.\flash_uart.bat

# Verificar se reset (D1) está em nível alto (3.3V)
# Se tiver botão pressionado, soltar!
```

### LEDs não respondem aos comandos

**Causa:** Comunicação UART não estabelecida

**Checklist:**
1. ✅ Cabos invertidos? TX→RX, RX→TX
2. ✅ GND compartilhado?
3. ✅ Baud rate correto (115200)?
4. ✅ Pico programado com `main.py`?

**Debug no Pico:**
```python
# Enviar e receber imediatamente
uart.write(b'\x01')
import time
time.sleep(0.1)
print(uart.read())  # Deve mostrar b'\xaa'
```

---

## 📚 Referências de Pinagem

- **Colorlight i9 Schematic:** [GitHub - wuxx/Colorlight](https://github.com/wuxx/Colorlight-FPGA-Projects/tree/master/colorlight_i9)
- **ECP5 Family Datasheet:** [Lattice Semiconductor](https://www.latticesemi.com/products/fpgaandcpld/ecp5)
- **Raspberry Pi Pico Pinout:** [pinout.xyz/pico](https://pico.pinout.xyz/)

---

**✅ Pinagem validada e testada para Colorlight i9 v7.2**
