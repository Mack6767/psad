#Used with ideas @netson from https://gist.github.com/netson/c45b2dc4e835761fbccc
#!/bin/bash

# Creating install log files for debugging
touch /home/${USER}/Documents/rsyslog_diag.log
touch /home/${USER}/Documents/ufw_install.log
touch /home/${USER}/Documents/fwsnort_install.log
touch /home/${USER}/Documents/psad_install.log
echo "Would you like to install PSAD & FWSnort? Please type Yes or No, followed by [ENTER]"
read install
if [[ $install == "Yes" ]]; then
  printf '\n%s\n' "Starting UFW and GUFW Installation and configuring for FWSnort with PSAD ......"; 
    {
      echo "First things first, lets get your network information. Please enter your nework in CIDR notation (192.168.1.0/24), followed by [ENTER]:"
      read network
      sudo su
      apt install ufw gufw -y
      ufw allow from $network app SSH
      ufw logging on
      sed -i.bak '/processed/i\# custom psad logging directives\n-A INPUT -j LOG --log-tcp-options --log-prefix "[IPTABLES] "\n-A FORWARD -j LOG --log-tcp-options --log-prefix "[IPTABLES] "\n' /etc/ufw/before.rules /etc/ufw/before6.rules /etc/ufw/after.rules /etc/ufw/after6.rules
      echo "# log kernel generated IPTABLES log messages to file
      # each log line will be prefixed by "[IPTABLES]", so search for that
      :msg,contains,"[IPTABLES]" /var/log/iptables.log
      # the following stops logging anything that matches the last rule.
      # doing this will stop logging kernel generated IPTABLES log messages to the file
      # normally containing kern.* messages (eg, /var/log/kern.log)
      # older versions of ubuntu may require you to change stop to ~
      & stop" >> /etc/rsyslog.d/10-iptables.conf
      exit
    } &> /home/${USER}/Documents/ufw_install.log
  printf '\n%s\n' "Checking if rsyslog is running ....";
    {
      sudo ps -C httpd >/dev/null && echo "Running" || echo "Not running"
      read check_one
      if [[ $check_one == "Running" ]]; then
        echo "Service is running"
      elif [[ $check_one == "Not running" ]]; then
        echo "Service is not running" && printf '\n%s\n' "Attempting to start rsyslog service ....";
        sudo service rsyslog start >/dev/null && ps -C httpd >/dev/null && echo "Running" || echo "Not running"
        read result
          if [[ $result == "Running" ]]; then
            echo "rsyslog service has been started"
          elif [[ $result == "Not running" ]]; then
            sudo systemctl list-unit-files | grep rsyslog
            echo "Does it show as 'masked'? Type Yes or No, followed by [ENTER]:"
            read masked
              if [[ $masked == "Yes" ]]; then
                sudo systemctl unmask rsyslog
                sudo service rsyslog start
              elif [[ $masked == "No" ]]; then
                sudo service rsyslog start && sudo ps -C httpd >/dev/null && echo "Running" || echo "Not running"
                read check_two
                  if [[ $check_two == "Not running" ]]; then
                    printf '\n%s\n' "Further diagnostics are required, start with journalctl -xe | grep rsyslog ...." && end
                  fi
              fi
          fi
      fi
  } &> /home/${USER}/Documents/rsyslog_diag.log
  printf '\n%s\n' "Starting FWSnort configuration ......";
    {
      sudo su
      apt install fwsnort -y
      echo "Make manual changes to fwsnort.conf located at /etc/fwsnort/fwsnort.conf:
      HOME_NET                YOUR_NETWORK_CIDR; #EX: 192.168.0.0/24
      EXTERNAL_NET            !$HOME_NET; #Denotes anything not within your network CIDR
      Add the following two lines to UPDATE_RULES_URL:
      UPDATE_RULES_URL        http://rules.emergingthreats.net/open/snort-edge/emerging-all.rules;
      UPDATE_RULES_URL        http://rules.emergingthreats.net/fwrules/emerging-IPTABLES-ALL.rules;"
      fwsnort --update-rules
      fwsnort -N --ipt-sync
      /sbin/iptables-restore < /var/lib/fwsnort/fwsnort.save
      # If you go the fwsnort.sh route, and you're not using 'sudo su' you're going to need this:
      # sudo sed -i '18748 s/^/#/' /var/lib/fwsnort/fwsnort.save 
      # Change the number to whatever line is having issues because IPTables is cray cray, rinse and repeat.
      # It will comment out that particular line and allow you to move forward. 
      exit
    } &> /home/${USER}/Documents/fwsnort_install.log
  printf '\n%s\n' "Starting PSAD configuration ......";
    {
      sudo su
      apt install psad -y
      echo "Make manual changes to psad.conf located at /etc/psad/psad.conf
      HOME_NET                    YOUR_NETWORK_CIDR; #EX: 192.168.0.0/24
      EXTERNAL_NET                !$HOME_NET; #Denotes anything not within your network CIDR
      ***In @netson's original post he points the log to psad-iptables.log, which isn't referenced anywhere else in the config, fixed the typo***
      IPT_SYSLOG_FILE             /var/log/iptables.log; #Points to the new log created earlier
      ENABLE_INTF_LOCAL_NETS         N; #Prevents PSAD from assuming the network automatically
      EXPECT_TCP_OPTIONS             Y;"
      psad -K
      psad --fw-include-ips
      exit
    } &> /home/${USER}/Documents/psad_install.log
elif [[ $install == "No" ]]; then
  echo "Exiting."
  exit
fi


