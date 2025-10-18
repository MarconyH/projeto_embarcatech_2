# 🚀 Guia Rápido - UART no Colorlight i9

## 📋 Checklist Rápido

- [ ] **Hardware:**
  - [ ] Colorlight i9 v7.2 (ECP5 LFE5U-45F)
  - [ ] Raspberry Pi Pico
  - [ ] 3 jumpers fêmea-fêmea
  - [ ] Cabo USB para Colorlight i9
  - [ ] Cabo USB para Raspberry Pi Pico

- [ ] **Software:**
  - [ ] OSS CAD Suite instalado em `C:\oss-cad-suite`
  - [ ] Thonny IDE (para programar o Pico)
  - [ ] MicroPython no Raspberry Pi Pico

---

## ⚡ Início Rápido (5 Passos)

### 1️⃣ Conectar Hardware

```
Colorlight i9                 Raspberry Pi Pico
─────────────                 ─────────────────
Pino E2 (TX) ──────────────► GP1 (RX)
Pino D2 (RX) ◄──────────────  GP0 (TX)
GND          ──────────────┬─ GND
                           │
USB ◄─────────────┐        └─ USB ◄──────────┐
                  │                           │
              Computador                 Computador
```

**⚠️ IMPORTANTE:** 
- Não conectar VCC do Pico ao FPGA
- Apenas GND, TX e RX
- Alimentar cada dispositivo por USB separadamente

---

### 2️⃣ Gravar FPGA

Abra PowerShell/CMD na pasta `UART-protocol`:

```powershell
cd "c:\Users\marco\Documents\Embarcatech\Projetos-Embarcatech\projeto_pratico_etapa_2\Teste FPGA Lattice\UART-protocol"

.\flash_uart.bat
```

**Saída esperada:**
```
============================================================
  UART SystemVerilog - Síntese para Colorlight i9
============================================================
[1/5] Verificando arquivos necessários...
✅ Todos os arquivos encontrados

[2/5] Síntese com Yosys...
✅ Síntese concluída com sucesso

[3/5] Place and Route com nextpnr-ecp5...
✅ Place and Route concluído

[4/5] Gerando bitstream com ecppack...
✅ Bitstream gerado: uart_example_colorlight_i9.bit

[5/5] Gravando no FPGA com openFPGALoader...
✅ FPGA gravado com sucesso!
```

---

### 3️⃣ Programar Raspberry Pi Pico

1. **Abrir Thonny IDE**
2. **Conectar Pico** (segure botão BOOTSEL + conectar USB)
3. **Instalar MicroPython** (se necessário):
   - Menu: Tools → Options → Interpreter
   - Selecionar "MicroPython (Raspberry Pi Pico)"
   - Clicar "Install or update MicroPython"

4. **Carregar script de teste:**
   - Abrir `test_fpga_uart.py`
   - Salvar no Pico como `main.py`
   - Menu: File → Save as → Raspberry Pi Pico → `main.py`

---

### 4️⃣ Executar Teste

No Thonny, pressione **F5** ou clique em **Run**.

**Menu interativo:**
```
==================================================
  Inicializando comunicação UART...
  Baudrate: 115200 | Pinos: TX=GP0, RX=GP1
==================================================

Selecione o modo de teste:
  1 - Sequência automática
  2 - Modo interativo
  3 - Teste contínuo
  4 - Sair

Opção: 
```

Escolha **1** para teste automático.

---

### 5️⃣ Verificar Resultados

**No Pico (Thonny Shell):**
```
[1/8] Apagar todos os LEDs
[TX] Enviado: 0x00
[RX] Resposta OK: 0xAA

[2/8] Acender LED 0
[TX] Enviado: 0x01
[RX] Resposta OK: 0xAA

...

==================================================
  Resultado: 8/8 testes OK
==================================================
```

**No FPGA (LEDs):**
- **LEDs[3:0]** (pinos B1, C2, C1, D3): Mudam conforme comandos
- **RX LED** (pino E3): Pisca ao receber comandos do Pico
- **TX LED** (pino F3): Pisca ao enviar confirmações (0xAA)

---

## 🔧 Troubleshooting

### Problema: "ERRO ao gravar FPGA!"

**Solução:**
```powershell
# Verificar se o FPGA está conectado
openFPGALoader --detect

# Deve mostrar:
# Jtag frequency : 6000000Hz
# index 0:
#   idcode 0x41111043
#   manufacturer lattice
#   family ECP5
#   model  LFE5U-45
```

---

### Problema: "Timeout - sem resposta do FPGA"

**Causas:**
1. Cabos invertidos (TX não conectado ao RX)
2. GND não compartilhado
3. FPGA não gravado corretamente
4. Baud rate diferente

**Verificação:**
```python
# No Thonny, digite:
uart.write(b'\x01')  # Envia comando
uart.read()           # Deve retornar b'\xaa' se FPGA responder
```

---

### Problema: LEDs não respondem

**Debug:**
1. **Verificar se FPGA foi gravado:**
   - RX LED (E3) e TX LED (F3) devem funcionar
   
2. **Testar loopback no Pico:**
   ```python
   from machine import UART, Pin
   uart = UART(0, 115200, tx=Pin(0), rx=Pin(1))
   
   # Conectar GP0 (TX) ao GP1 (RX) com jumper
   uart.write(b'\x42')
   print(uart.read())  # Deve mostrar b'B' (0x42)
   ```

3. **Medir sinais com LED:**
   - Conectar LED + resistor entre TX/RX e GND
   - Deve piscar ao enviar dados

---

## 📊 Tabela de Comandos

| Comando | Hex  | Efeito no FPGA             |
|---------|------|----------------------------|
| 0       | 0x00 | Apaga todos os LEDs        |
| 1       | 0x01 | Acende LED 0 (pino B1)     |
| 2       | 0x02 | Acende LEDs 0-1            |
| 3       | 0x03 | Acende LEDs 0-2            |
| 4       | 0x04 | Acende todos (LED 0-3)     |
| 16      | 0x10 | Inverte estado de todos    |
| 255     | 0xFF | Padrão teste (0b1010)      |

**Resposta do FPGA:** Sempre 0xAA (sucesso)

---

## 🎯 Teste Manual Rápido

```python
# Copiar/colar no Thonny Shell após rodar main.py

from machine import UART, Pin
uart = UART(0, 115200, tx=Pin(0), rx=Pin(1))

# Apagar LEDs
uart.write(b'\x00')
print(f"Resposta: {uart.read()}")  # Espera: b'\xaa'

# Acender todos
uart.write(b'\x04')
print(f"Resposta: {uart.read()}")  # Espera: b'\xaa'

# Inverter
uart.write(b'\x10')
print(f"Resposta: {uart.read()}")  # Espera: b'\xaa'
```

---

## 📈 Especificações Técnicas

| Parâmetro            | Valor                     |
|----------------------|---------------------------|
| FPGA                 | Lattice ECP5 LFE5U-45F    |
| Clock FPGA           | 25 MHz (oscilador P3)     |
| Baud Rate            | 115200                    |
| CLKS_PER_BIT         | 217 (25M / 115200)        |
| Formato              | 8N1 (8 bits, sem paridade)|
| Níveis Lógicos       | 3.3V (compatível Pico)    |
| Latência TX→RX       | ~0.9 ms (104 bits @ 115200)|

---

## 📁 Arquivos do Projeto

```
UART-protocol/
├── uart_tx.sv                        # Transmissor UART
├── uart_rx.sv                        # Receptor UART
├── uart_top.sv                       # Integração TX+RX
├── uart_example_colorlight_i9.sv     # Exemplo para i9 (use este!)
├── uart_colorlight_i9.lpf            # Pinagem Colorlight i9
├── flash_uart.bat                    # Script de síntese/gravação
├── test_fpga_uart.py                 # Script Python para Pico
├── README_UART.md                    # Documentação completa
└── QUICKSTART_COLORLIGHT_I9.md       # Este arquivo
```

---

## ✅ Checklist de Validação

Após completar todos os passos, você deve ter:

- [ ] ✅ FPGA gravado (mensagem "FPGA gravado com sucesso!")
- [ ] ✅ Pico programado (main.py carregado)
- [ ] ✅ Cabos conectados (TX→RX cruzados + GND)
- [ ] ✅ Teste executado (8/8 testes OK)
- [ ] ✅ LEDs respondendo aos comandos
- [ ] ✅ RX LED e TX LED piscando

**🎉 Parabéns! Sistema UART funcionando!**

---

## 🔗 Links Úteis

- **Colorlight i9 Pinout:** [GitHub - Colorlight i9](https://github.com/wuxx/Colorlight-FPGA-Projects)
- **Raspberry Pi Pico UART:** [Documentação Oficial](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf)
- **OSS CAD Suite:** [YosysHQ](https://github.com/YosysHQ/oss-cad-suite-build)
- **MicroPython:** [micropython.org](https://micropython.org/)

---

**Última atualização:** Otimizado para Colorlight i9 @ 25 MHz  
**Projeto:** Embarcatech - Etapa 2  
**Status:** ✅ Pronto para uso
