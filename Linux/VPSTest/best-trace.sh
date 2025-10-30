wget https://benchs.pika.net.cn/best-trace/besttrace4linux.zip
unzip besttrace4linux.zip
chmod +x besttrace

# 交互式输入IP地址
echo "请输入要追踪的IP地址 (默认: 114.114.114.114):"
read -r target_ip

# 如果用户没有输入，使用默认IP
if [ -z "$target_ip" ]; then
    target_ip="114.114.114.114"
fi

echo "正在追踪路由到 $target_ip ..."
./besttrace -q1 "$target_ip"