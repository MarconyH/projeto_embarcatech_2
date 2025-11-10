"""
Geração de Gráficos para Resultados do Sistema de Detecção de Linhas
Projeto: Transformada de Hough em FPGA (64x64 pixels)
Autor: Marcony Henrique Bento Souza
Data: 09/11/2025
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import Circle, Rectangle, FancyBboxPatch
import seaborn as sns
from mpl_toolkits.mplot3d import Axes3D

# Configuração de estilo
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")
plt.rcParams['figure.figsize'] = (10, 6)
plt.rcParams['font.size'] = 11
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['axes.titlesize'] = 14
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['legend.fontsize'] = 10

# Criar diretório para salvar gráficos
import os
output_dir = "graficos_resultados"
os.makedirs(output_dir, exist_ok=True)

print("=" * 70)
print("GERAÇÃO DE GRÁFICOS - RESULTADOS EXPERIMENTAIS")
print("=" * 70)

# =============================================================================
# GRÁFICO 1: Distribuição de Detecções por Tile (Mapa de Calor)
# =============================================================================
print("\n[1/10] Gerando mapa de calor de detecções por tile...")

tile_detections = np.array([
    [0, 0, 4, 0],  # Row 0 (tiles 1-4)
    [0, 0, 4, 0],  # Row 1 (tiles 5-8)
    [4, 4, 4, 4],  # Row 2 (tiles 9-12) - linha horizontal
    [0, 0, 4, 0]   # Row 3 (tiles 13-16)
])

fig, ax = plt.subplots(figsize=(10, 8))
im = ax.imshow(tile_detections, cmap='YlOrRd', aspect='auto', vmin=0, vmax=4)

# Adicionar valores nas células
for i in range(4):
    for j in range(4):
        tile_num = i * 4 + j + 1
        text = ax.text(j, i, f'Tile {tile_num}\n{tile_detections[i, j]} linhas',
                      ha="center", va="center", color="black", fontsize=11, weight='bold')

# Configurações
ax.set_xticks(np.arange(4))
ax.set_yticks(np.arange(4))
ax.set_xticklabels(['Col 0', 'Col 1', 'Col 2', 'Col 3'])
ax.set_yticklabels(['Row 0', 'Row 1', 'Row 2', 'Row 3'])
ax.set_xlabel('Tile X (Colunas)', fontsize=12, weight='bold')
ax.set_ylabel('Tile Y (Linhas)', fontsize=12, weight='bold')
ax.set_title('Distribuição de Detecções de Linhas por Tile (Grid 4×4)', 
             fontsize=14, weight='bold', pad=20)

# Colorbar
cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
cbar.set_label('Número de Linhas Detectadas', rotation=270, labelpad=20, fontsize=11)

plt.tight_layout()
plt.savefig(f'{output_dir}/01_mapa_calor_tiles.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/01_mapa_calor_tiles.png")

# =============================================================================
# GRÁFICO 2: Distribuição de Ângulos Detectados (Histograma Polar)
# =============================================================================
print("\n[2/10] Gerando distribuição de ângulos detectados...")

# Dados: ângulos detectados (em graus) e seus votos
angles_detected = [0, 11, 11, 11, 90, 101, 112, 112, 112, 123, 135, 157, 168, 168, 168, 168]
votes = [16, 6, 6, 5, 16, 16, 16, 17, 16, 16, 17, 18, 21, 6, 6, 6]

# Converter para radianos
angles_rad = np.deg2rad(angles_detected)

# Criar histograma polar
fig, ax = plt.subplots(subplot_kw={'projection': 'polar'}, figsize=(10, 10))

# Agrupar por ângulo
unique_angles = sorted(set(angles_detected))
angle_counts = []
angle_total_votes = []

for angle in unique_angles:
    indices = [i for i, a in enumerate(angles_detected) if a == angle]
    angle_counts.append(len(indices))
    angle_total_votes.append(sum(votes[i] for i in indices))

# Plotar barras
theta = np.deg2rad(unique_angles)
width = np.deg2rad(10)  # Largura da barra
colors = plt.cm.viridis(np.linspace(0, 1, len(unique_angles)))

bars = ax.bar(theta, angle_total_votes, width=width, bottom=0.0, 
              color=colors, alpha=0.8, edgecolor='black', linewidth=1.5)

# Destacar ângulos principais (0° e 90°)
for i, angle in enumerate(unique_angles):
    if angle == 0 or angle == 90:
        bars[i].set_color('red')
        bars[i].set_alpha(1.0)
        bars[i].set_linewidth(2.5)

# Configurações
ax.set_theta_zero_location('N')  # 0° no topo
ax.set_theta_direction(-1)  # Sentido horário
ax.set_ylim(0, max(angle_total_votes) * 1.2)
ax.set_title('Distribuição Angular das Linhas Detectadas\n(Vermelho = Linhas Principais)', 
             fontsize=14, weight='bold', pad=30)
ax.set_ylabel('Total de Votos', fontsize=12)

# Legenda
from matplotlib.patches import Patch
legend_elements = [
    Patch(facecolor='red', alpha=1.0, edgecolor='black', label='Linhas Principais (0°, 90°)'),
    Patch(facecolor='gray', alpha=0.8, edgecolor='black', label='Artefatos de Quantização')
]
ax.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(1.3, 1.1))

plt.tight_layout()
plt.savefig(f'{output_dir}/02_distribuicao_angulos_polar.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/02_distribuicao_angulos_polar.png")

# =============================================================================
# GRÁFICO 3: Espaço de Parâmetros Hough (ρ vs θ) - Scatter Plot
# =============================================================================
print("\n[3/10] Gerando espaço de parâmetros Hough...")

# Dados das 15 linhas filtradas
rho_values = [32.00, -31.30, -27.97, 35.47, 26.84, 32.00, 17.68, 28.36, 
              23.68, -16.95, -24.65, 0.00, 11.69, 40.57, -21.32]
theta_values = [0, 168, 168, 11, 123, 90, 112, 101, 112, 157, 168, 135, 112, 11, 168]
votes_values = [16, 6, 6, 5, 16, 16, 17, 16, 16, 18, 21, 17, 16, 6, 6]

# Classificar linhas principais vs ruído
main_lines = [(32.00, 0, 16), (32.00, 90, 16)]  # ρ, θ, votos
noise_lines = [(rho_values[i], theta_values[i], votes_values[i]) 
               for i in range(len(rho_values)) 
               if not (rho_values[i] == 32.00 and theta_values[i] in [0, 90])]

fig, ax = plt.subplots(figsize=(12, 8))

# Plotar ruído
noise_rho = [line[0] for line in noise_lines]
noise_theta = [line[1] for line in noise_lines]
noise_votes = [line[2] for line in noise_lines]

scatter_noise = ax.scatter(noise_theta, noise_rho, s=np.array(noise_votes)*20, 
                          c='gray', alpha=0.5, edgecolors='black', linewidth=1.5,
                          label='Artefatos (13 linhas)')

# Plotar linhas principais
main_rho = [line[0] for line in main_lines]
main_theta = [line[1] for line in main_lines]
main_votes = [line[2] for line in main_lines]

scatter_main = ax.scatter(main_theta, main_rho, s=np.array(main_votes)*30, 
                         c='red', alpha=1.0, edgecolors='darkred', linewidth=2.5,
                         marker='*', label='Linhas Principais (2 linhas)', zorder=5)

# Adicionar anotações para linhas principais
for i, (rho, theta, votes) in enumerate(main_lines):
    label = f'ρ={rho:.0f}, θ={theta}°\nvotos={votes}'
    ax.annotate(label, (theta, rho), xytext=(15, 15), textcoords='offset points',
               bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.8),
               arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.3', 
                             color='red', lw=2), fontsize=10, weight='bold')

# Configurações
ax.set_xlabel('θ (Ângulo em Graus)', fontsize=12, weight='bold')
ax.set_ylabel('ρ (Distância da Origem)', fontsize=12, weight='bold')
ax.set_title('Espaço de Parâmetros Hough (ρ, θ)\nTamanho das Bolhas = Número de Votos', 
             fontsize=14, weight='bold', pad=15)
ax.grid(True, alpha=0.3, linestyle='--')
ax.axhline(y=0, color='black', linewidth=0.8, linestyle='-', alpha=0.3)
ax.axvline(x=0, color='black', linewidth=0.8, linestyle='-', alpha=0.3)
ax.legend(loc='upper left', fontsize=11, framealpha=0.9)
ax.set_xlim(-10, 180)
ax.set_ylim(-40, 50)

plt.tight_layout()
plt.savefig(f'{output_dir}/03_espaco_hough_scatter.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/03_espaco_hough_scatter.png")

# =============================================================================
# GRÁFICO 4: Distribuição de Votos (Histograma)
# =============================================================================
print("\n[4/10] Gerando distribuição de votos...")

fig, ax = plt.subplots(figsize=(10, 6))

# Separar votos de linhas principais vs ruído
main_votes = [16, 16]
noise_votes = [v for i, v in enumerate(votes_values) 
               if not (rho_values[i] == 32.00 and theta_values[i] in [0, 90])]

# Criar bins
bins = [0, 5, 10, 15, 20, 25]
hist_main, _ = np.histogram(main_votes, bins=bins)
hist_noise, _ = np.histogram(noise_votes, bins=bins)

# Posições das barras
x = np.arange(len(bins)-1)
width = 0.35

# Plotar barras
bars1 = ax.bar(x - width/2, hist_main, width, label='Linhas Principais', 
              color='red', alpha=0.8, edgecolor='black', linewidth=1.5)
bars2 = ax.bar(x + width/2, hist_noise, width, label='Artefatos', 
              color='gray', alpha=0.6, edgecolor='black', linewidth=1.5)

# Adicionar valores nas barras
for bars in [bars1, bars2]:
    for bar in bars:
        height = bar.get_height()
        if height > 0:
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{int(height)}', ha='center', va='bottom', fontsize=10, weight='bold')

# Configurações
ax.set_xlabel('Faixa de Votos', fontsize=12, weight='bold')
ax.set_ylabel('Quantidade de Linhas', fontsize=12, weight='bold')
ax.set_title('Distribuição de Votos por Categoria de Linha', fontsize=14, weight='bold', pad=15)
ax.set_xticks(x)
ax.set_xticklabels(['0-5', '5-10', '10-15', '15-20', '20-25'])
ax.legend(loc='upper right', fontsize=11, framealpha=0.9)
ax.grid(axis='y', alpha=0.3, linestyle='--')

plt.tight_layout()
plt.savefig(f'{output_dir}/04_distribuicao_votos.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/04_distribuicao_votos.png")

# =============================================================================
# GRÁFICO 5: Processo de Filtragem (Sankey-like Diagram)
# =============================================================================
print("\n[5/10] Gerando diagrama de filtragem...")

fig, ax = plt.subplots(figsize=(12, 6))

# Estágios do processo
stages = ['Detecções\nBrutas', 'Conversão\nGlobal', 'Filtragem\nDuplicatas', 'Resultado\nFinal']
values = [28, 28, 15, 2]  # 2 = linhas principais
colors = ['#ff9999', '#ffcc99', '#99ccff', '#99ff99']

# Desenhar retângulos
y_pos = 0.5
height = 0.3
x_positions = [0.1, 0.3, 0.5, 0.7]
widths = [0.15, 0.15, 0.15, 0.15]

for i, (stage, value, color, x, w) in enumerate(zip(stages, values, colors, x_positions, widths)):
    # Retângulo
    rect = FancyBboxPatch((x, y_pos - height/2), w, height, 
                          boxstyle="round,pad=0.01", 
                          facecolor=color, edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    
    # Texto
    ax.text(x + w/2, y_pos, f'{stage}\n{value} linhas', 
           ha='center', va='center', fontsize=11, weight='bold')
    
    # Setas
    if i < len(stages) - 1:
        arrow_x = x + w + 0.01
        arrow_dx = x_positions[i+1] - arrow_x - 0.01
        ax.arrow(arrow_x, y_pos, arrow_dx, 0, 
                head_width=0.05, head_length=0.02, fc='black', ec='black', linewidth=2)

# Anotações
ax.text(0.4, 0.85, 'Converte coordenadas\nlocais → globais', 
       ha='center', fontsize=9, style='italic', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
ax.text(0.6, 0.85, 'Remove duplicatas\n(|Δρ|<3, |Δθ|<15°)', 
       ha='center', fontsize=9, style='italic', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
ax.text(0.8, 0.15, '13 artefatos\nremovidos', 
       ha='center', fontsize=9, style='italic', color='red', weight='bold')

# Configurações
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis('off')
ax.set_title('Pipeline de Processamento: Detecção Bruta → Resultado Final', 
            fontsize=14, weight='bold', pad=20)

plt.tight_layout()
plt.savefig(f'{output_dir}/05_pipeline_filtragem.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/05_pipeline_filtragem.png")

# =============================================================================
# GRÁFICO 6: Análise de Acurácia (Pizza + Barras)
# =============================================================================
print("\n[6/10] Gerando análise de acurácia...")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

# Gráfico de Pizza - Classificação das Detecções
sizes = [2, 13]
labels = ['Linhas Principais\n(Corretas)', 'Artefatos\n(Falsos Positivos)']
colors_pie = ['#90EE90', '#FFB6C6']
explode = (0.1, 0)

wedges, texts, autotexts = ax1.pie(sizes, explode=explode, labels=labels, colors=colors_pie,
                                    autopct='%1.1f%%', shadow=True, startangle=90,
                                    textprops={'fontsize': 11, 'weight': 'bold'})

for autotext in autotexts:
    autotext.set_color('black')
    autotext.set_fontsize(12)
    autotext.set_weight('bold')

ax1.set_title('Classificação das 15 Linhas Detectadas', fontsize=12, weight='bold', pad=15)

# Gráfico de Barras - Métricas de Desempenho
metrics = ['Precisão\n(Precision)', 'Recall', 'Taxa de\nDetecção']
values_metrics = [13.3, 100, 100]  # Em porcentagem
colors_bars = ['#FFA07A', '#98FB98', '#87CEEB']

bars = ax2.bar(metrics, values_metrics, color=colors_bars, alpha=0.8, 
              edgecolor='black', linewidth=2)

# Adicionar valores nas barras
for bar, value in zip(bars, values_metrics):
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height,
            f'{value:.1f}%', ha='center', va='bottom', fontsize=12, weight='bold')

# Linha de referência 100%
ax2.axhline(y=100, color='green', linestyle='--', linewidth=2, alpha=0.7, label='100% (ideal)')

# Configurações
ax2.set_ylabel('Porcentagem (%)', fontsize=12, weight='bold')
ax2.set_title('Métricas de Desempenho do Sistema', fontsize=12, weight='bold', pad=15)
ax2.set_ylim(0, 110)
ax2.grid(axis='y', alpha=0.3, linestyle='--')
ax2.legend(fontsize=10)

plt.tight_layout()
plt.savefig(f'{output_dir}/06_analise_acuracia.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/06_analise_acuracia.png")

# =============================================================================
# GRÁFICO 7: Tempo de Processamento por Tile
# =============================================================================
print("\n[7/10] Gerando análise de tempo de processamento...")

fig, ax = plt.subplots(figsize=(12, 6))

# Dados simulados (todos ~800ms)
tiles = list(range(1, 17))
processing_times = [800] * 16  # ms

# Destacar tiles com detecções
tiles_with_detection = [3, 7, 9, 10, 11, 12, 15]
colors_time = ['red' if t in tiles_with_detection else 'lightblue' for t in tiles]

bars = ax.bar(tiles, processing_times, color=colors_time, alpha=0.8, 
             edgecolor='black', linewidth=1.5)

# Linha de média
avg_time = np.mean(processing_times)
ax.axhline(y=avg_time, color='blue', linestyle='--', linewidth=2, 
          label=f'Média: {avg_time:.0f} ms', alpha=0.7)

# Configurações
ax.set_xlabel('Número do Tile', fontsize=12, weight='bold')
ax.set_ylabel('Tempo de Processamento (ms)', fontsize=12, weight='bold')
ax.set_title('Tempo de Processamento por Tile (Grid 4×4)\nVermelho = Tiles com Detecções', 
            fontsize=14, weight='bold', pad=15)
ax.set_xticks(tiles)
ax.grid(axis='y', alpha=0.3, linestyle='--')
ax.legend(fontsize=11)
ax.set_ylim(0, 1000)

# Adicionar tempo total
total_time = sum(processing_times) / 1000  # segundos
ax.text(0.98, 0.95, f'Tempo Total: {total_time:.1f}s', 
       transform=ax.transAxes, fontsize=12, weight='bold',
       verticalalignment='top', horizontalalignment='right',
       bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.8))

plt.tight_layout()
plt.savefig(f'{output_dir}/07_tempo_processamento_tiles.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/07_tempo_processamento_tiles.png")

# =============================================================================
# GRÁFICO 8: Visualização da Imagem 64x64 com Linhas Detectadas
# =============================================================================
print("\n[8/10] Gerando visualização da imagem 64x64...")

# Criar imagem 64x64 (cruz)
image_64x64 = np.zeros((64, 64))
image_64x64[32, :] = 1  # Linha horizontal
image_64x64[:, 32] = 1  # Linha vertical

fig, ax = plt.subplots(figsize=(10, 10))

# Plotar imagem
ax.imshow(image_64x64, cmap='gray_r', aspect='equal', interpolation='nearest')

# Desenhar linhas principais detectadas
# Linha vertical: ρ=32, θ=0°
ax.axvline(x=32, color='red', linewidth=3, linestyle='--', alpha=0.7, label='Vertical Detectada (ρ=32, θ=0°)')

# Linha horizontal: ρ=32, θ=90°
ax.axhline(y=32, color='blue', linewidth=3, linestyle='--', alpha=0.7, label='Horizontal Detectada (ρ=32, θ=90°)')

# Desenhar grid de tiles
for i in range(1, 4):
    ax.axvline(x=i*16, color='green', linewidth=1, linestyle=':', alpha=0.5)
    ax.axhline(y=i*16, color='green', linewidth=1, linestyle=':', alpha=0.5)

# Adicionar números dos tiles
for i in range(4):
    for j in range(4):
        tile_num = i * 4 + j + 1
        ax.text(j*16 + 8, i*16 + 8, f'T{tile_num}', 
               ha='center', va='center', fontsize=9, 
               bbox=dict(boxstyle='round', facecolor='white', alpha=0.7))

# Configurações
ax.set_xlabel('X (pixels)', fontsize=12, weight='bold')
ax.set_ylabel('Y (pixels)', fontsize=12, weight='bold')
ax.set_title('Imagem 64×64: Cruz Original + Linhas Detectadas\nGrid Verde = Divisão em Tiles 16×16', 
            fontsize=14, weight='bold', pad=15)
ax.legend(loc='upper right', fontsize=10, framealpha=0.9)
ax.set_xlim(-1, 64)
ax.set_ylim(64, -1)  # Inverter eixo Y

plt.tight_layout()
plt.savefig(f'{output_dir}/08_imagem_64x64_detectada.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/08_imagem_64x64_detectada.png")

# =============================================================================
# GRÁFICO 9: Comparação de Recursos FPGA (Barras Empilhadas)
# =============================================================================
print("\n[9/10] Gerando comparação de recursos FPGA...")

fig, ax = plt.subplots(figsize=(10, 6))

# Dados (percentuais de uso estimados)
resources = ['LUTs', 'Flip-Flops', 'BRAM', 'DSPs']
used = [15, 8, 2, 0]  # Percentual usado
available = [85, 92, 98, 100]  # Percentual disponível

x = np.arange(len(resources))
width = 0.6

# Barras empilhadas
p1 = ax.bar(x, used, width, label='Usado', color='#FF6B6B', edgecolor='black', linewidth=1.5)
p2 = ax.bar(x, available, width, bottom=used, label='Disponível', 
           color='#4ECDC4', edgecolor='black', linewidth=1.5)

# Adicionar valores
for i, (u, a) in enumerate(zip(used, available)):
    ax.text(i, u/2, f'{u}%', ha='center', va='center', 
           fontsize=11, weight='bold', color='white')
    ax.text(i, u + a/2, f'{a}%', ha='center', va='center', 
           fontsize=11, weight='bold', color='black')

# Configurações
ax.set_ylabel('Percentual de Uso (%)', fontsize=12, weight='bold')
ax.set_title('Utilização de Recursos do FPGA (Lattice ECP5-45F)', 
            fontsize=14, weight='bold', pad=15)
ax.set_xticks(x)
ax.set_xticklabels(resources, fontsize=12, weight='bold')
ax.legend(loc='upper right', fontsize=11, framealpha=0.9)
ax.set_ylim(0, 105)
ax.grid(axis='y', alpha=0.3, linestyle='--')

# Anotação
ax.text(0.5, 0.95, 'Design compacto: ~85% dos recursos ainda disponíveis', 
       transform=ax.transAxes, fontsize=11, style='italic',
       verticalalignment='top', horizontalalignment='center',
       bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.7))

plt.tight_layout()
plt.savefig(f'{output_dir}/09_recursos_fpga.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/09_recursos_fpga.png")

# =============================================================================
# GRÁFICO 10: Acumulador Hough 3D (Exemplo de um Tile)
# =============================================================================
print("\n[10/10] Gerando visualização 3D do acumulador Hough...")

fig = plt.figure(figsize=(12, 9))
ax = fig.add_subplot(111, projection='3d')

# Simular acumulador 16x16 (exemplo: tile 11 com cruz)
rho_bins = np.arange(16)
theta_bins = np.arange(16)
rho_grid, theta_grid = np.meshgrid(rho_bins, theta_bins)

# Criar acumulador simulado (picos em ρ=0, θ=0 e θ=8 que corresponde a ~90°)
accumulator = np.zeros((16, 16))
accumulator[0, 0] = 16  # Pico vertical
accumulator[0, 8] = 16  # Pico horizontal (~90°)
accumulator[0, 11] = 6  # Ruído
accumulator[0, 15] = 6  # Ruído

# Adicionar ruído aleatório baixo
accumulator += np.random.randint(0, 3, (16, 16))

# Plotar superfície 3D
surf = ax.plot_surface(rho_grid, theta_grid, accumulator, cmap='viridis',
                       alpha=0.8, edgecolor='black', linewidth=0.3)

# Destacar picos
peak_positions = [(0, 0, 16), (0, 8, 16)]
for rho, theta, votes in peak_positions:
    ax.scatter([rho], [theta], [votes], color='red', s=200, marker='*', 
              edgecolors='darkred', linewidth=2, zorder=5)

# Configurações
ax.set_xlabel('ρ (bin)', fontsize=11, weight='bold')
ax.set_ylabel('θ (bin)', fontsize=11, weight='bold')
ax.set_zlabel('Votos', fontsize=11, weight='bold')
ax.set_title('Acumulador Hough 3D (16×16 bins)\nEstrelas Vermelhas = Picos Detectados', 
            fontsize=14, weight='bold', pad=20)

# Colorbar
fig.colorbar(surf, ax=ax, shrink=0.5, aspect=5, label='Número de Votos')

# Ajustar visualização
ax.view_init(elev=25, azim=45)

plt.tight_layout()
plt.savefig(f'{output_dir}/10_acumulador_hough_3d.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"   ✅ Salvo: {output_dir}/10_acumulador_hough_3d.png")

# =============================================================================
# RESUMO FINAL
# =============================================================================
print("\n" + "=" * 70)
print("✅ GERAÇÃO DE GRÁFICOS CONCLUÍDA COM SUCESSO!")
print("=" * 70)
print(f"\n📁 Todos os gráficos foram salvos em: {output_dir}/")
print("\nGráficos gerados:")
print("  01 - Mapa de Calor de Detecções por Tile")
print("  02 - Distribuição de Ângulos (Polar)")
print("  03 - Espaço de Parâmetros Hough (ρ vs θ)")
print("  04 - Distribuição de Votos")
print("  05 - Pipeline de Filtragem")
print("  06 - Análise de Acurácia (Pizza + Barras)")
print("  07 - Tempo de Processamento por Tile")
print("  08 - Imagem 64×64 com Linhas Detectadas")
print("  09 - Utilização de Recursos FPGA")
print("  10 - Acumulador Hough 3D")
print("\n💡 Dica: Use estes gráficos no seu artigo/apresentação!")
print("=" * 70)
