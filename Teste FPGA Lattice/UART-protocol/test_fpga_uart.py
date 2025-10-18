# test_fpga_uart.py
# Script MicroPython para Raspberry Pi Pico
# Testa comunicação UART com FPGA
#
# Configuração:
#   - Conectar Pico TX (GP0) ao FPGA RX
#   - Conectar Pico RX (GP1) ao FPGA TX
#   - Compartilhar GND entre Pico e FPGA
#
# Carregar no Pico usando Thonny ou rshell

from machine import UART, Pin
import time

# Configuração UART
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
uart.init(bits=8, parity=None, stop=1)

# LED integrado do Pico para debug
led = Pin(25, Pin.OUT)

def blink_led(times=1):
    """Pisca LED do Pico"""
    for _ in range(times):
        led.value(1)
        time.sleep(0.1)
        led.value(0)
        time.sleep(0.1)

def send_command(cmd, timeout_ms=100):
    """
    Envia comando para FPGA e aguarda resposta 0xAA
    
    Args:
        cmd: Byte de comando (0x00-0xFF)
        timeout_ms: Tempo máximo de espera pela resposta
        
    Returns:
        True se recebeu 0xAA, False caso contrário
    """
    # Limpa buffer de recepção
    while uart.any():
        uart.read()
    
    # Envia comando
    uart.write(bytes([cmd]))
    print(f"[TX] Enviado: 0x{cmd:02X}")
    
    # Aguarda resposta
    start = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start) < timeout_ms:
        if uart.any():
            response = uart.read(1)
            if response and response[0] == 0xAA:
                print(f"[RX] Resposta OK: 0x{response[0]:02X}")
                blink_led(1)
                return True
            else:
                print(f"[RX] Resposta inesperada: 0x{response[0]:02X}")
                return False
        time.sleep_ms(5)
    
    print("[RX] Timeout - sem resposta do FPGA")
    return False

def test_sequence():
    """Executa sequência de teste completa"""
    print("\n" + "="*50)
    print("  TESTE UART FPGA <-> Raspberry Pi Pico")
    print("="*50)
    
    tests = [
        (0x00, "Apagar todos os LEDs"),
        (0x01, "Acender LED 0"),
        (0x02, "Acender LEDs 0-1"),
        (0x03, "Acender LEDs 0-2"),
        (0x04, "Acender todos os LEDs"),
        (0x10, "Inverter estado dos LEDs"),
        (0xFF, "Padrão de teste (0b1010)"),
        (0x00, "Apagar todos os LEDs")
    ]
    
    success_count = 0
    
    for i, (cmd, description) in enumerate(tests, 1):
        print(f"\n[{i}/{len(tests)}] {description}")
        if send_command(cmd):
            success_count += 1
        time.sleep(1)  # Aguarda 1 segundo entre comandos
    
    print("\n" + "="*50)
    print(f"  Resultado: {success_count}/{len(tests)} testes OK")
    print("="*50 + "\n")
    
    return success_count == len(tests)

def interactive_mode():
    """Modo interativo para enviar comandos manualmente"""
    print("\n=== MODO INTERATIVO ===")
    print("Comandos disponíveis:")
    print("  0x00 - Apagar LEDs")
    print("  0x01 - LED 0")
    print("  0x02 - LEDs 0-1")
    print("  0x03 - LEDs 0-2")
    print("  0x04 - Todos os LEDs")
    print("  0x10 - Inverter LEDs")
    print("  0xFF - Padrão teste")
    print("  'q' - Sair\n")
    
    while True:
        try:
            user_input = input("Digite comando (hex, ex: 0x01): ").strip().lower()
            
            if user_input == 'q':
                print("Encerrando modo interativo...")
                break
            
            # Converte string para inteiro
            if user_input.startswith('0x'):
                cmd = int(user_input, 16)
            else:
                cmd = int(user_input)
            
            if 0 <= cmd <= 255:
                send_command(cmd)
            else:
                print("Erro: comando deve estar entre 0x00 e 0xFF")
                
        except ValueError:
            print("Erro: formato inválido. Use 0x01 ou apenas 1")
        except KeyboardInterrupt:
            print("\nInterrompido pelo usuário")
            break

def continuous_test():
    """Teste contínuo para verificar estabilidade"""
    print("\n=== TESTE CONTÍNUO (Pressione Ctrl+C para parar) ===\n")
    
    cycle = 0
    errors = 0
    
    try:
        while True:
            cycle += 1
            print(f"Ciclo {cycle} - Erros: {errors}", end="\r")
            
            # Sequência rápida
            commands = [0x00, 0x04, 0x10]
            for cmd in commands:
                if not send_command(cmd, timeout_ms=50):
                    errors += 1
                time.sleep_ms(100)
                
    except KeyboardInterrupt:
        print(f"\n\nTeste interrompido após {cycle} ciclos")
        print(f"Taxa de erro: {errors}/{cycle*3} ({100*errors/(cycle*3):.2f}%)")

def main():
    """Função principal"""
    print("\n" + "="*50)
    print("  Inicializando comunicação UART...")
    print("  Baudrate: 115200 | Pinos: TX=GP0, RX=GP1")
    print("="*50)
    
    # Pisca LED 3 vezes para indicar início
    blink_led(3)
    time.sleep(1)
    
    # Menu principal
    while True:
        print("\nSelecione o modo de teste:")
        print("  1 - Sequência automática")
        print("  2 - Modo interativo")
        print("  3 - Teste contínuo")
        print("  4 - Sair")
        
        choice = input("\nOpção: ").strip()
        
        if choice == '1':
            test_sequence()
        elif choice == '2':
            interactive_mode()
        elif choice == '3':
            continuous_test()
        elif choice == '4':
            print("Encerrando...")
            break
        else:
            print("Opção inválida!")

# Executa automaticamente se for o script principal
if __name__ == "__main__":
    main()
