function add_transparent_proxy() {
  sudo iptables -t nat -N REDSOCKS
  sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 100.64.0.0/10 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 198.18.0.0/15 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
  sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
  sudo iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
  sudo service redsocks restart
}

add_transparent_proxy