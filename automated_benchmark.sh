#!/bin/bash
# Complete benchmark automation with report generation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DURATION=${DURATION:-90s}
CONNECTIONS=${CONNECTIONS:-100}
THREADS=${THREADS:-4}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results_${TIMESTAMP}"

# Test endpoints configuration
declare -A ENDPOINTS=(
    ["hello"]="/"
    ["json"]="/json"
    ["params"]="/user/123"
    ["query"]="/search?q=benchmark&limit=100"
)

# Server configurations: name:port:directory:binary
SERVERS=(
    "fiber_v3:3001:fiber:fiber_v3.go"
    "gin:3002:gin:gin_server.go"
)

echo -e "${BLUE}=== Automated Benchmark Suite ===${NC}"
echo "Configuration:"
echo "  Duration: $DURATION"
echo "  Connections: $CONNECTIONS"
echo "  Threads: $THREADS"
echo "  Results Directory: $RESULTS_DIR"
echo "  Endpoints: ${!ENDPOINTS[@]}"
echo "  Servers: fiber_v3, gin"
echo

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to start server
start_server() {
    local server_name=$1
    local port=$2
    local directory=$3
    local binary=$4
    
    echo -e "${YELLOW}Starting $server_name server on port $port...${NC}"
    
    cd "servers/$directory"
    go run "$binary" "$port" &
    local pid=$!
    cd ../..
    
    # Wait for server to start
    sleep 3
    
    # Test if server is responding
    local max_retries=5
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -s "http://localhost:$port/" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $server_name server started successfully${NC}"
            echo $pid
            return 0
        fi
        retry=$((retry + 1))
        echo "Waiting for $server_name server... (attempt $retry/$max_retries)"
        sleep 2
    done
    
    echo -e "${RED}✗ Failed to start $server_name server${NC}"
    kill $pid 2>/dev/null || true
    return 1
}

# Function to stop server
stop_server() {
    local pid=$1
    local server_name=$2
    
    if [ ! -z "$pid" ] && [ "$pid" != "0" ]; then
        echo -e "${YELLOW}Stopping $server_name server (PID: $pid)...${NC}"
        kill $pid 2>/dev/null || true
        sleep 2
        kill -9 $pid 2>/dev/null || true
    fi
}

# Function to run benchmark for one endpoint
run_benchmark() {
    local server_name=$1
    local port=$2
    local endpoint_name=$3
    local endpoint_path=$4
    
    local url="http://localhost:$port$endpoint_path"
    local output_file="$RESULTS_DIR/${server_name}_${endpoint_name}.txt"
    
    echo -e "${GREEN}Testing $server_name - $endpoint_name${NC}"
    echo "URL: $url"
    
    # Handle POST endpoints differently
    if [[ "$endpoint_path" == *"/user"* ]] && [[ "$endpoint_name" == "post"* ]]; then
        # POST JSON endpoint
        local lua_script="$RESULTS_DIR/post_json.lua"
        cat > "$lua_script" << 'EOF'
wrk.method = "POST"
wrk.body   = '{"name":"John Doe","email":"john@example.com"}'
wrk.headers["Content-Type"] = "application/json"
EOF
        wrk -t$THREADS -c$CONNECTIONS -d$DURATION -s "$lua_script" "$url" > "$output_file"
    elif [[ "$endpoint_path" == *"/form"* ]]; then
        # POST form endpoint
        local lua_script="$RESULTS_DIR/post_form.lua"
        cat > "$lua_script" << 'EOF'
wrk.method = "POST"
wrk.body   = "name=John&email=john@example.com"
wrk.headers["Content-Type"] = "application/x-www-form-urlencoded"
EOF
        wrk -t$THREADS -c$CONNECTIONS -d$DURATION -s "$lua_script" "$url" > "$output_file"
    else
        # GET endpoints
        wrk -t$THREADS -c$CONNECTIONS -d$DURATION "$url" > "$output_file"
    fi
    
    # Extract and display key metrics
    local rps=$(grep "Requests/sec:" "$output_file" | awk '{print $2}' || echo "N/A")
    local latency=$(grep "Latency" "$output_file" | head -1 | awk '{print $2}' || echo "N/A")
    local transfer=$(grep "Transfer/sec:" "$output_file" | awk '{print $2}' || echo "N/A")
    
    echo "  RPS: $rps, Latency: $latency, Transfer: $transfer"
    echo
}

# Function to test all endpoints for a server
test_server_endpoints() {
    local server_info=$1
    
    IFS=':' read -ra SERVER_PARTS <<< "$server_info"
    local server_name="${SERVER_PARTS[0]}"
    local port="${SERVER_PARTS[1]}"
    local directory="${SERVER_PARTS[2]}"
    local binary="${SERVER_PARTS[3]}"
    
    echo -e "${BLUE}=== Testing $server_name ===${NC}"
    
    # Start server
    local server_pid
    server_pid=$(start_server "$server_name" "$port" "$directory" "$binary")
    
    if [ $? -ne 0 ] || [ -z "$server_pid" ]; then
        echo -e "${RED}Skipping $server_name due to startup failure${NC}"
        return 1
    fi
    
    # Test all endpoints
    for endpoint_name in "${!ENDPOINTS[@]}"; do
        run_benchmark "$server_name" "$port" "$endpoint_name" "${ENDPOINTS[$endpoint_name]}"
    done
    
    # Stop server
    stop_server "$server_pid" "$server_name"
    
    echo -e "${GREEN}Completed testing $server_name${NC}"
    echo
    
    return 0
}

# Function to generate comparison report
generate_text_report() {
    echo -e "${BLUE}Generating text comparison report...${NC}"
    
    local report_file="$RESULTS_DIR/benchmark_comparison.txt"
    
    cat > "$report_file" << EOF
FIBER v3 vs GIN - BENCHMARK REPORT
===============================================
Generated: $(date)
Configuration: ${DURATION} duration, ${CONNECTIONS} connections, ${THREADS} threads

EOF
    
    # For each endpoint, compare all servers
    for endpoint_name in "${!ENDPOINTS[@]}"; do
        echo "=== $endpoint_name (${ENDPOINTS[$endpoint_name]}) ===" >> "$report_file"
        echo "" >> "$report_file"
        
        # Extract metrics for each server
        for server_info in "${SERVERS[@]}"; do
            IFS=':' read -ra SERVER_PARTS <<< "$server_info"
            local server_name="${SERVER_PARTS[0]}"
            local result_file="$RESULTS_DIR/${server_name}_${endpoint_name}.txt"
            
            if [ -f "$result_file" ]; then
                local rps=$(grep "Requests/sec:" "$result_file" | awk '{print $2}' | sed 's/[^0-9.]//g' || echo "0")
                local latency=$(grep "Latency" "$result_file" | head -1 | awk '{print $2}' || echo "N/A")
                local transfer=$(grep "Transfer/sec:" "$result_file" | awk '{print $2}' || echo "N/A")
                local errors=$(grep "Non-2xx or 3xx responses:" "$result_file" | awk '{print $4}' || echo "0")
                
                printf "%-10s: %10s RPS, %8s latency, %10s transfer, %s errors\n" \
                    "$server_name" "$rps" "$latency" "$transfer" "$errors" >> "$report_file"
            else
                printf "%-10s: No results available\n" "$server_name" >> "$report_file"
            fi
        done
        
        echo "" >> "$report_file"
    done
    
    echo -e "${GREEN}Text report saved: $report_file${NC}"
}

# Function to generate visual reports using Python
generate_visual_reports() {
    echo -e "${BLUE}Generating visual reports and charts...${NC}"
    
    # Check if Python and required libraries are available
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}Python3 not found. Skipping visual report generation.${NC}"
        echo "Install Python3 and run: pip3 install matplotlib pandas numpy seaborn reportlab"
        return 1
    fi
    
    # Create a comprehensive analysis script
    cat > "$RESULTS_DIR/analyze_all.py" << 'EOF'
#!/usr/bin/env ./venv/bin/python
import os
import re
import sys
import glob
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np
    import seaborn as sns
except ImportError as e:
    print(f"Missing required packages: {e}")
    print("Install with: pip3 install matplotlib pandas numpy seaborn")
    sys.exit(1)

def parse_wrk_output(file_path):
    """Parse wrk output file"""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        result = {}
        
        # Extract RPS
        rps_match = re.search(r'Requests/sec:\s+(\d+\.?\d*)', content)
        if rps_match:
            result['rps'] = float(rps_match.group(1))
        
        # Extract latency (convert to ms)
        latency_match = re.search(r'Latency\s+(\d+\.?\d*)(us|ms|s)', content)
        if latency_match:
            value = float(latency_match.group(1))
            unit = latency_match.group(2)
            if unit == 'us':
                result['latency_ms'] = value / 1000
            elif unit == 's':
                result['latency_ms'] = value * 1000
            else:
                result['latency_ms'] = value
        
        # Extract transfer rate (convert to MB/s)
        transfer_match = re.search(r'Transfer/sec:\s+([\d.]+)(KB|MB|GB)', content)
        if transfer_match:
            value = float(transfer_match.group(1))
            unit = transfer_match.group(2)
            if unit == 'KB':
                result['transfer_mb'] = value / 1024
            elif unit == 'GB':
                result['transfer_mb'] = value * 1024
            else:
                result['transfer_mb'] = value
        
        # Extract errors
        error_match = re.search(r'Non-2xx or 3xx responses: (\d+)', content)
        result['errors'] = int(error_match.group(1)) if error_match else 0
        
        return result
    
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        return {}

def main():
    # Find all result files
    result_files = glob.glob("*.txt")
    
    # Parse results by server and endpoint
    data = {}
    servers = set()
    endpoints = set()
    
    for file_path in result_files:
        if '_' in Path(file_path).stem amd not file_path.endswith('benchmark_comparison.txt'):
            server, endpoint = Path(file_path).stem.split('_', 1)
            servers.add(server)
            endpoints.add(endpoint)
            
            if endpoint not in data:
                data[endpoint] = {}
            
            data[endpoint][server] = parse_wrk_output(file_path)
    
    if not data:
        print("No benchmark results found!")
        return
    
    servers = sorted(list(servers))
    endpoints = sorted(list(endpoints))
    
    print(f"Found results for servers: {servers}")
    print(f"Found results for endpoints: {endpoints}")
    
    # Create comprehensive comparison charts
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle('Go Web Framework Benchmark Comparison', fontsize=16, fontweight='bold')
    
    colors = plt.cm.Set3(np.linspace(0, 1, len(servers)))
    
    # Chart 1: RPS by Endpoint
    ax1 = axes[0, 0]
    x = np.arange(len(endpoints))
    width = 0.25
    
    for i, server in enumerate(servers):
        rps_values = []
        for endpoint in endpoints:
            rps = data.get(endpoint, {}).get(server, {}).get('rps', 0)
            rps_values.append(rps)
        
        ax1.bar(x + i * width, rps_values, width, label=server, color=colors[i])
    
    ax1.set_xlabel('Endpoints')
    ax1.set_ylabel('Requests per Second')
    ax1.set_title('Throughput Comparison by Endpoint')
    ax1.set_xticks(x + width)
    ax1.set_xticklabels(endpoints, rotation=45)
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # Chart 2: Latency by Endpoint
    ax2 = axes[0, 1]
    for i, server in enumerate(servers):
        latency_values = []
        for endpoint in endpoints:
            latency = data.get(endpoint, {}).get(server, {}).get('latency_ms', 0)
            latency_values.append(latency)
        
        ax2.bar(x + i * width, latency_values, width, label=server, color=colors[i])
    
    ax2.set_xlabel('Endpoints')
    ax2.set_ylabel('Latency (ms)')
    ax2.set_title('Latency Comparison by Endpoint (Lower is Better)')
    ax2.set_xticks(x + width)
    ax2.set_xticklabels(endpoints, rotation=45)
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # Chart 3: Transfer Rate by Endpoint
    ax3 = axes[1, 0]
    for i, server in enumerate(servers):
        transfer_values = []
        for endpoint in endpoints:
            transfer = data.get(endpoint, {}).get(server, {}).get('transfer_mb', 0)
            transfer_values.append(transfer)
        
        ax3.bar(x + i * width, transfer_values, width, label=server, color=colors[i])
    
    ax3.set_xlabel('Endpoints')
    ax3.set_ylabel('Transfer Rate (MB/s)')
    ax3.set_title('Transfer Rate Comparison by Endpoint')
    ax3.set_xticks(x + width)
    ax3.set_xticklabels(endpoints, rotation=45)
    ax3.legend()
    ax3.grid(True, alpha=0.3)
    
    # Chart 4: Average Performance Summary
    ax4 = axes[1, 1]
    
    # Calculate average metrics across all endpoints
    avg_metrics = {}
    for server in servers:
        total_rps = 0
        total_latency = 0
        total_transfer = 0
        count = 0
        
        for endpoint in endpoints:
            endpoint_data = data.get(endpoint, {}).get(server, {})
            if endpoint_data:
                total_rps += endpoint_data.get('rps', 0)
                total_latency += endpoint_data.get('latency_ms', 0)
                total_transfer += endpoint_data.get('transfer_mb', 0)
                count += 1
        
        if count > 0:
            avg_metrics[server] = {
                'avg_rps': total_rps / count,
                'avg_latency': total_latency / count,
                'avg_transfer': total_transfer / count
            }
    
    # Create summary table
    ax4.axis('tight')
    ax4.axis('off')
    
    table_data = [['Framework', 'Avg RPS', 'Avg Latency (ms)', 'Avg Transfer (MB/s)']]
    for server in servers:
        if server in avg_metrics:
            metrics = avg_metrics[server]
            table_data.append([
                server,
                f"{metrics['avg_rps']:,.0f}",
                f"{metrics['avg_latency']:.2f}",
                f"{metrics['avg_transfer']:.2f}"
            ])
    
    table = ax4.table(cellText=table_data, loc='center', cellLoc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 2)
    
    # Style the header row
    for j in range(len(table_data[0])):
        table[(0, j)].set_facecolor('#4CAF50')
        table[(0, j)].set_text_props(weight='bold', color='white')
    
    ax4.set_title('Average Performance Summary')
    
    plt.tight_layout()
    plt.savefig('benchmark_comparison.png', dpi=300, bbox_inches='tight')
    print("✓ Benchmark comparison chart saved: benchmark_comparison.png")
    
    # Create individual endpoint charts
    for endpoint in endpoints:
        if endpoint in data:
            plt.figure(figsize=(12, 8))
            
            # Create subplot for this endpoint
            fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(15, 5))
            fig.suptitle(f'Performance Comparison - {endpoint.upper()} Endpoint', fontsize=14, fontweight='bold')
            
            server_names = []
            rps_vals = []
            latency_vals = []
            transfer_vals = []
            
            for server in servers:
                if server in data[endpoint]:
                    server_names.append(server)
                    rps_vals.append(data[endpoint][server].get('rps', 0))
                    latency_vals.append(data[endpoint][server].get('latency_ms', 0))
                    transfer_vals.append(data[endpoint][server].get('transfer_mb', 0))
            
            # RPS chart
            bars1 = ax1.bar(server_names, rps_vals, color=colors[:len(server_names)])
            ax1.set_ylabel('Requests per Second')
            ax1.set_title('Throughput')
            for bar, val in zip(bars1, rps_vals):
                ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(rps_vals)*0.01,
                        f'{val:,.0f}', ha='center', va='bottom', fontweight='bold')
            
            # Latency chart
            bars2 = ax2.bar(server_names, latency_vals, color=colors[:len(server_names)])
            ax2.set_ylabel('Latency (ms)')
            ax2.set_title('Response Time')
            for bar, val in zip(bars2, latency_vals):
                ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(latency_vals)*0.01,
                        f'{val:.2f}', ha='center', va='bottom', fontweight='bold')
            
            # Transfer chart
            bars3 = ax3.bar(server_names, transfer_vals, color=colors[:len(server_names)])
            ax3.set_ylabel('Transfer (MB/s)')
            ax3.set_title('Data Transfer')
            for bar, val in zip(bars3, transfer_vals):
                ax3.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(transfer_vals)*0.01,
                        f'{val:.2f}', ha='center', va='bottom', fontweight='bold')
            
            plt.tight_layout()
            plt.savefig(f'{endpoint}_comparison.png', dpi=300, bbox_inches='tight')
            plt.close()
            print(f"✓ {endpoint} endpoint chart saved: {endpoint}_comparison.png")
    
    print(f"\n✓ All charts generated successfully!")

if __name__ == "__main__":
    main()
EOF
    
    # Run the Python analysis
    cd "$RESULTS_DIR"
    if python3 analyze_all.py; then
        echo -e "${GREEN}✓ Visual reports generated successfully${NC}"
        echo "Charts saved in $RESULTS_DIR/"
    else
        echo -e "${YELLOW}Visual report generation failed. Check Python dependencies.${NC}"
    fi
    cd ..
}

# Main execution
echo -e "${BLUE}Starting comprehensive benchmark...${NC}"

# Test all servers
for server_info in "${SERVERS[@]}"; do
    test_server_endpoints "$server_info"
done

# Generate reports
generate_text_report
generate_visual_reports

echo -e "${GREEN}=== Benchmark Complete! ===${NC}"
echo "Results are available in: $RESULTS_DIR/"
echo ""
echo "Generated files:"
echo "  - benchmark_comparison.txt (text report)"
echo "  - *.png (charts and visualizations)"
echo ""
echo -e "${BLUE}Summary:${NC}"
ls -la "$RESULTS_DIR"/*.txt "$RESULTS_DIR"/*.png 2>/dev/null || echo "Check $RESULTS_DIR/ for all generated files"