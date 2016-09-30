echo Installing dependencies...
sudo apt-get update
sudo apt-get install -y unzip curl

cd /tmp/
sudo curl https://releases.hashicorp.com/nomad/0.4.0/nomad_0.4.0_linux_amd64.zip -o nomad.zip

sudo mkdir /opt/nomad
sudo mkdir /etc/nomad.d/

echo Installing Nomad...
sudo useradd --system nomad --shell /usr/sbin/nologin
sudo unzip nomad.zip
sudo chmod +x nomad
sudo mv nomad /opt/nomad/nomad
sudo chown nomad:nomad /opt/nomad
sudo chown nomad:nomad /etc/nomad.d
