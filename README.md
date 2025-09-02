# Fiber v3 vs Gin Performance Benchmark

A comprehensive benchmarking suite comparing **Fiber v3** and **Gin** Go web frameworks across multiple endpoints and metrics.

## Project Structure

```
benchmark_fiber_gin/
├── README.md                    # This file
├── automated_benchmark.sh       # Main benchmark script
├── venv/                       # Python virtual environment (created during setup)
├── requirements.txt            # Python dependencies
└── servers/
    ├── fiber/
    │   ├── fiber_v3.go         # Fiber v3 server
    │   ├── go.mod
    │   └── go.sum
    └── gin/
        ├── gin_server.go       # Gin server
        ├── go.mod
        └── go.sum
```

## Prerequisites

- **Go 1.24+** (required for Fiber v3)
- **Python 3.9+** (for analysis and reporting)
- **wrk** (HTTP benchmarking tool)
- **curl** (for server health checks)

### Installing Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install golang-go python3 python3-pip python3-venv wrk curl
```

**macOS:**
```bash
brew install go python3 wrk curl
```

**Arch Linux:**
```bash
sudo pacman -S go python python-pip wrk curl
```

## Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/zrougamed/benchmark_fiber_gin.git
cd benchmark_fiber_gin
```

### 2. Create Python Virtual Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows
```

### 3. Install Python Dependencies
```bash
# Create requirements.txt
cat > requirements.txt << 'EOF'
matplotlib>=3.5.0
pandas>=1.3.0
numpy>=1.21.0
seaborn>=0.11.0
reportlab>=3.6.0
EOF

# Install dependencies
pip install -r requirements.txt
```


### 4. Run Benchmark
```bash
# Make benchmark script executable
chmod +x automated_benchmark.sh

# Run default benchmark (60s)
./automated_benchmark.sh

# Or run with custom settings
DURATION=30s CONNECTIONS=50 ./automated_benchmark.sh
```

## Configuration Options

### Environment Variables

```bash
# Benchmark duration (default: 60s)
export DURATION=90s

# Number of concurrent connections (default: 100)
export CONNECTIONS=200

# Number of threads (default: 4)
export THREADS=8

# Run custom benchmark
./automated_benchmark.sh
```

### Benchmark Profiles

```bash
# Quick test (30s, light load)
DURATION=30s CONNECTIONS=50 THREADS=2 ./automated_benchmark.sh

# Standard test (60s, moderate load)  
DURATION=60s CONNECTIONS=100 THREADS=4 ./automated_benchmark.sh

# Stress test (120s, heavy load)
DURATION=120s CONNECTIONS=500 THREADS=8 ./automated_benchmark.sh
```

## What You'll Get

### Generated Files

After running the benchmark, you'll find:

```
results_TIMESTAMP/
├── fiber_hello.txt         # Fiber hello world results
├── fiber_json.txt          # Fiber JSON endpoint results
├── fiber_params.txt        # Fiber URL params results
├── fiber_query.txt         # Fiber query params results
├── gin_hello.txt           # Gin hello world results
├── gin_json.txt            # Gin JSON endpoint results
├── gin_params.txt          # Gin URL params results
├── gin_query.txt           # Gin query params results
├── benchmark_comparison.txt # Text comparison report
├── performance_comparison.png # Visual comparison charts
└── analysis_report.txt     # Analysis summary
```

### Endpoints Tested

| Endpoint | Description | URL |
|----------|-------------|-----|
| **Hello** | Simple string response | `/` |
| **JSON** | JSON object response | `/json` |
| **Params** | URL parameter parsing | `/user/123` |
| **Query** | Query string parsing | `/search?q=test&limit=100` |

### Metrics Measured

- **Requests per Second (RPS)** - Higher is better
- **Average Latency** - Lower is better  
- **Transfer Rate (MB/s)** - Data throughput
- **Error Rate** - Should be zero

## Expected Results

Based on typical benchmarks, you should expect:

- **Fiber v3**: 200k-250k RPS, ~0.5ms latency
- **Gin**: 140k-180k RPS, ~1.5ms latency
- **Fiber advantage**: ~40-50% higher throughput, ~60% lower latency

## Performance Insights

### Why Fiber v3 Performs Better

- **FastHTTP Foundation**: Built on fasthttp vs Gin's net/http
- **Zero-Copy Operations**: Minimizes memory allocations
- **Optimized Routing**: Efficient request routing algorithm
- **Memory Management**: Better garbage collection characteristics

### When to Choose Each

**Choose Fiber v3 for:**
- High-performance APIs
- Microservices
- Real-time applications
- Cost-sensitive deployments

**Choose Gin for:**
- Traditional web applications
- When ecosystem compatibility matters
- Teams familiar with net/http patterns
- Gradual migration scenarios

## Contributing

1. Fork the repository
2. Create feature branch
3. Add new benchmark scenarios
4. Submit pull request

## License

MIT License - feel free to use and modify!

---

**Happy Benchmarking! May the fastest framework win! 🏆**
Made with ❤️ by [Mohamed Zrouga](https://zrouga.email)
