#!/bin/bash

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Continue with this parameters?? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
esac
}

install_mkcert() {
  echo "mkcert not found installing it"
  sudo apt install libnss3-tools
  rm ./mkcert-v*-linux-amd64 2> /dev/null
  curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
  chmod +x mkcert-v*-linux-amd64
  sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
}

remove(){
  [ ! -d /etc/mkcert ] && sudo mkdir /etc/mkcert
  [  -f "/etc/mkcert/$domain.pem" ] && sudo rm -f "/etc/mkcert/$domain.pem"
  [  -f "/etc/mkcert/$domain-key.pem" ] && sudo rm -f "/etc/mkcert/$domain-key.pem"
  [  -f "/etc/nginx/sites-enabled/$domain" ] && sudo rm -f  "/etc/nginx/sites-enabled/$domain"
  [  -f "/etc/nginx/sites-available/$domain" ] && sudo rm -f "/etc/nginx/sites-available/$domain"
  sudo sed -i "/$domain.*#MLS/d" /etc/hosts

}

create() {
  remove
  cd /etc/mkcert
  sudo mkcert $domain
  echo "
  server {                                                                              
      listen 443 ssl;                                                                   
      ssl_certificate /etc/mkcert/$domain.pem;
      ssl_certificate_key /etc/mkcert/$domain-key.pem;      
      add_header X-Frame-Options \"SAMEORIGIN\";
      add_header X-XSS-Protection \"1; mode=block\";
      add_header X-Content-Type-Options \"nosniff\";
      charset utf-8;  

      location / {
          try_files \$uri \$uri/ /index.php?\$query_string;
      }
      location = /favicon.ico { access_log off; log_not_found off; }
      location = /robots.txt  { access_log off; log_not_found off; }
      error_page 404 /index.php;

      server_name $domain;                                                        
      root $path ;                                                
      index index.php index.html;                                                                
      location ~ \.php$ {
         try_files \$uri = 404;
          fastcgi_split_path_info ^(.+\.php)(/.+)\$;
          fastcgi_pass unix:/var/run/php/php-fpm.sock;
          fastcgi_index index.php;
          include fastcgi_params;
          fastcgi_param REQUEST_URI \$request_uri;
          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_param PATH_INFO \$fastcgi_path_info; 
     }

      location ~ /\.(?!well-known).* {
          deny all;
      }
  }
  " | sudo tee "/etc/nginx/sites-available/$domain" > /dev/null
  sudo ln -s "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"
  echo "127.0.0.1 $domain #MLS" | sudo tee -a  /etc/hosts > /dev/null
  sudo systemctl restart nginx
}

while getopts p:d:u: flag
do
    case "${flag}" in
        p) path=${OPTARG};;
        d) domain=${OPTARG};;
        u) remove_domain=${OPTARG};;
    esac
done
if [ -n "$remove_domain" ]
then
  confirm
  domain=$remove_domain
  remove
  sudo systemctl restart nginx
  exit
fi
  

command -v sudo nginx > /dev/null 2>&1 || sudo apt install nginx
command -v mkcert > /dev/null 2>&1 || install_mkcert

read -p "Enter Domain: "  domain
read -e -p "Enter the path/to/project/folder: " path

echo "Path: $path";
echo "Domain: $domain";  
confirm && create 




