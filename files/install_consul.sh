echo Installing dependencies...
sudo apt-get update
sudo apt-get install -y unzip curl

echo Fetching Consul...

cd /tmp/
sudo curl https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip -o consul.zip

echo Installing Consul...
sudo useradd --system consul --shell /usr/sbin/nologin
sudo mkdir /opt/consul/
sudo unzip consul.zip
sudo chmod +x consul
sudo mv consul /opt/consul/consul
sudo mkdir /etc/consul.d
sudo chmod a+w /etc/consul.d
sudo chown consul:consul /opt/consul
sudo chown consul:consul /etc/consul.d
