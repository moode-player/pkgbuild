cat /opt/camillagui/config/camillagui.yml  |grep bind_address|| echo "bind_address: \"0.0.0.0\"" >> /opt/camillagui/config/camillagui.yml
if [ -f /opt/camillagui/config/gui-config.yml ]
then
  echo "Move old /opt/camillagui/config/gui-config.yml to /opt/camillagui/config/gui-config.yml.old"
  mv -f /opt/camillagui/config/gui-config.yml /opt/camillagui/config/gui-config.yml.old
else
  echo "No /opt/camillagui/config/gui-config.yml present yet"
fi
ln -s /opt/camillagui/config/gui-config.yml.basic /opt/camillagui/config/gui-config.yml 
