# JaimeCirne Workflow

Este repositório contém um pipeline para análise de dados de BLAST MegaBLAST, processamento, armazenamento em MySQL e geração de relatórios interativos via servidor web.

---

## Estrutura do Projeto

```text
JaimeCirne_workflow/
├── blast/
│   └── megakegg          # Saída bruta do MegaBLAST
├── mysql/
│   ├── schema.sql        # Definição do schema do banco
│   ├── load_data.sql     # Scripts de carga e transformação (LOAD DATA, CREATE TABLE, UPDATE)
│   └── queries.sql       # Consultas SQL padrão
├── process_results.py    # Conversão do BLAST para tabular e contagem de CDS
├── view_results.py       # Geração de relatório HTML e servidor HTTP
├── run_analysis.sh       # Orquestrador: BLAST → Python → MySQL → relatórios
├── resultado             # Saída de contagem de hits por CDS
├── megakegg_tab          # Saída tabular do BLAST (input para MySQL)
└── .venv/                # Virtual environment Python
```

---

## Pré-requisitos

* **Linux** (ou Unix-like)
* **Bash** (`#!/usr/bin/env bash`)
* **Python 3.8+**

  * pacotes: `pandas`, `pymysql`, `matplotlib`
* **MySQL** (ou MariaDB) com suporte a `LOCAL_INFILE`
* **MegaBLAST** (parte do NCBI BLAST+)
* **Virtualenv** (opcional, mas recomendado)

---

## Instalação e Setup

1. Clone este repositório:

   ```bash
   git clone https://github.com/seu_usuario/JaimeCirne_workflow.git
   cd JaimeCirne_workflow
   ```

2. Crie e ative o virtualenv Python:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install pandas pymysql matplotlib
   ```

3. Ajuste permissões de execução:

   ```bash
   chmod +x run_analysis.sh process_results.py view_results.py
   ```

4. Edite as variáveis de ambiente (opcional):

   ```bash
   export MYSQL_USER=bif01
   export MYSQL_PASS=bif01
   export DB_NAME=JaimeCirne
   ```

---

## Uso

### 1. Executar o pipeline completo:

```bash
./run_analysis.sh
```

Esse script irá:

1. Preparar diretórios e copiar arquivos de entrada.
2. Rodar MegaBLAST (`megablast`).
3. Processar saída com `process_results.py` (gera `resultado` e `megakegg_tab`).
4. Inicializar o schema MySQL e carregar dados (`load_data.sql`).
5. Executar consultas ad-hoc e imprimir no terminal.
6. Gerar relatório HTML e iniciar servidor web (via `view_results.py`).

### 2. Acessar relatório interativo:

Após o passo acima, abra no navegador:

```
http://localhost:8080/report
```

Você verá:

* Tabelas resumidas (Top Genes, Top KOs, Pathways, etc.)
* Gráficos de barras verticais/horizontais
* Matriz de correlação
* Download dos arquivos brutos
* Tabelas completas para inspeção

---

## Scripts Principais

* `run_analysis.sh` – Orquestra todo o pipeline.
* `process_results.py` – Converte BLAST em formato tabular e conta hits por CDS.
* `view_results.py` – Conecta ao MySQL, gera relatório HTML completo e serve via HTTP.

---

## Licença

MIT © JaimeCirne

---

*Desenvolvido por JaimeCirne*
