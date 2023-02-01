#!/bin/sh

# WAN Failover for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 1/31/2023
# Version: v1.6.1-beta2

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="wan-failover"
VERSION="v1.6.1-beta2"
README="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover-readme-beta.txt"
CONFIGFILE="/jffs/configs/wan-failover.conf"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
WANPREFIXES="wan0 wan1"
WAN0="wan0"
WAN1="wan1"
NOCOLOR="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[94m"
WHITE="\033[37m"

if [[ "$(dirname "$0")" == "." ]] >/dev/null 2>&1;then
  if [ ! -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}***WARNING*** Do Not Execute as "$0". Execute using Alias: ${BLUE}$ALIAS${RED}${NOCOLOR}.${NOCOLOR}"
  else
    SCRIPTPATH="/jffs/scripts/"${0##*/}""
    echo -e ""${BOLD}"${RED}***WARNING*** Do Not Execute as "$0". Execute using full script path ${BLUE}"$SCRIPTPATH"${NOCOLOR}.${NOCOLOR}"
  fi
  exit
fi

# Set Script Mode
[ "$#" == "0" ] && mode=${mode:=menu}
[ "$#" != "0" ] && mode="${1#}"
if [ "$#" == "2" ] >/dev/null 2>&1;then
  arg2=$2
elif [ "$#" == "1" ] >/dev/null 2>&1;then
  arg2=0
fi
scriptmode ()
{
if [[ "${mode}" == "menu" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    trap 'return' EXIT HUP INT QUIT TERM
    systembinaries || return
    [ -f "$CONFIGFILE" ] && { setvariables || return ;}
    menu || return
  else
    return
  fi
elif [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${BLUE}${0##*/} - Install Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  install
elif [[ "${mode}" == "config" ]] >/dev/null 2>&1;then 
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}${0##*/} - Configuration Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  install
elif [[ "${mode}" == "run" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}${0##*/} - Run Mode${NOCOLOR}"
  fi
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  logger -p 6 -t "${0##*/}" "Debug - Locked File: "$LOCKFILE""
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "manual" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
  fi
  exec 100>"$LOCKFILE" || return
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && return ;}
  logger -p 6 -t "${0##*/}" "Debug - Locked File: "$LOCKFILE""
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "initiate" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}${0##*/} - Initiate Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "restart" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  fi
  killscript
elif [[ "${mode}" == "monitor" ]] || [[ "${mode}" == "capture" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    [[ "${mode}" == "monitor" ]] && echo -e ""${BOLD}"${GREEN}${0##*/} - Monitor Mode${NOCOLOR}"
    [[ "${mode}" == "capture" ]] && echo -e ""${BOLD}"${GREEN}${0##*/} - Capture Mode${NOCOLOR}"
  fi
  trap 'exit' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to kill background process on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  monitor
elif [[ "${mode}" == "kill" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}${0##*/} - Kill Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  killscript
elif [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}${0##*/} - Uninstall Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}${0##*/} - Cron Job Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  setvariables || return
  cronjob
elif [[ "${mode}" == "switchwan" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}${0##*/} - Switch WAN Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}***Switch WAN Mode is only available in Failover Mode***${NOCOLOR}"
    return
  elif [[ "$(nvram get wans_mode)" != "lb" ]] >/dev/null 2>&1;then
    while [[ "${mode}" == "switchwan" ]] >/dev/null 2>&1;do
      if tty >/dev/null 2>&1;then
        read -p "Are you sure you want to switch Primary WAN? ***Enter Y for Yes or N for No***" yn
        case $yn in
          [Yy]* ) break;;
          [Nn]* ) return;;
          * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
        esac
      else
        break
      fi
    done
    systembinaries || return
    setvariables || return
    failover || return
  fi
elif [[ "${mode}" == "update" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}${0##*/} - Update Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  update
elif [[ "${mode}" == "email" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}${0##*/} - Email Configuration Mode${NOCOLOR}"
  fi
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  if [ "$arg2" == "0" ] >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}Select (enable) or (disable)${NOCOLOR}"
    exit
  elif [ "$arg2" == "enable" ] || [ "$arg2" == "disable" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Email Configuration Changing to $arg2"
    OPTION=$arg2
    sendemail
  fi
fi
}

# Menu
menu () {
	clear
	sed -n '2,6p' "${0}"		# Display Banner
        printf "\n"
        printf "  ${BOLD}Information:${NOCOLOR}\n"
	printf "  (1)  status      Status Information about WAN Failover\n"
   	printf "  (2)  readme      View WAN Failover Readme\n"
     
        printf "\n"
        printf "  ${BOLD}Installation/Configuration:${NOCOLOR}\n"
	printf "  (3)  install     Install WAN Failover\n"
	printf "  (4)  uninstall   Uninstall WAN Failover\n"
	printf "  (5)  config      Configuration of WAN Failover\n"
	printf "  (6)  update      Check for updates for WAN Failover\n"
        printf "\n"
        printf "  ${BOLD}Operations:${NOCOLOR}\n"
        printf "  (7)  run         Schedule WAN Failover to run via Cron Job\n"
	printf "  (8)  manual      Execute WAN Failover from Interactive Console\n"
	printf "  (9)  initiate    Execute WAN Failover to only create Routing Table Rules, IP Rules, and IPTable Rules\n"
	printf "  (10) monitor     Monitor System Log for WAN Failover Events\n"
	printf "  (11) capture     Capture System Log for WAN Failover Events\n"
	printf "  (12) restart     Restart WAN Failover\n"
	printf "  (13) kill        Kill all instances of WAN Failover and unschedule Cron Jobs\n"
        [[ "$(nvram get wans_mode)" != "lb" ]] && printf "  (14) switchwan   Manually switch Primary WAN.  ${RED}***Failover Mode Only***${NOCOLOR}\n"


	printf "\n  (e)  exit        Exit WAN Failover Menu\n"
	printf "\nMake a selection: "
	read -r input
	case "${input}" in
		'')
                        return
		;;
		'1')
                        printf "${BOLD}WAN Failover Status:${NOCOLOR}\n"
                        echo -e "${BOLD}Version: ${NOCOLOR}${BLUE}"$VERSION"${NOCOLOR}"
                        [[ "$(nvram get wans_dualwan | awk '{print $2}')" != "none" ]] && echo -e "${BOLD}Dual WAN:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}"
                        [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && echo -e "${BOLD}Dual WAN:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
                        [[ "$(nvram get wans_mode)" == "lb" ]] && echo -e "${BOLD}Mode: ${NOCOLOR}${BLUE}Load Balance Mode${NOCOLOR}"
                        [[ "$(nvram get wans_mode)" != "lb" ]] && echo -e "${BOLD}Mode: ${NOCOLOR}${BLUE}Failover Mode${NOCOLOR}"
                        [[ "$(nvram get jffs2_scripts)" == "1" ]] && echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}"
                        [[ "$(nvram get jffs2_scripts)" != "1" ]] && echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
                        [ ! -z "$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')" ] && echo -e "${BOLD}Status:${NOCOLOR} ${GREEN}Running${NOCOLOR}"
                        [ -z "$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')" ] && echo -e "${BOLD}Status:${NOCOLOR} ${RED}Not Running${NOCOLOR}"
                        printf "\n"
                        printf "${BOLD}WAN0:${NOCOLOR}\n"
                        [[ "$(nvram get wan0_enable)" == "1" ]] && echo -e "${BOLD}Status: ${NOCOLOR}${GREEN}Enabled${NOCOLOR}"
                        [[ "$(nvram get wan0_enable)" == "0" ]] && echo -e "${BOLD}Status: ${NOCOLOR}${RED}Disabled${NOCOLOR}"
                        [ ! -z "$(nvram get wan0_ipaddr)" ] && echo -e "${BOLD}IP Address: ${NOCOLOR}${BLUE}"$(nvram get wan0_ipaddr)"${NOCOLOR}"
                        [ ! -z "$(nvram get wan0_gateway)" ] && echo -e "${BOLD}Gateway: ${NOCOLOR}${BLUE}"$(nvram get wan0_gateway)"${NOCOLOR}"
                        [ ! -z "$(nvram get wan0_gw_ifname)" ] && echo -e "${BOLD}Interface: ${NOCOLOR}${BLUE}"$(nvram get wan0_gw_ifname)"${NOCOLOR}"
                        printf "\n"
                        printf "${BOLD}WAN1:${NOCOLOR}\n"
                        [[ "$(nvram get wan1_enable)" == "1" ]] && echo -e "${BOLD}Status: ${NOCOLOR}${GREEN}Enabled${NOCOLOR}"
                        [[ "$(nvram get wan1_enable)" == "0" ]] && echo -e "${BOLD}Status: ${NOCOLOR}${RED}Disabled${NOCOLOR}"
                        [ ! -z "$(nvram get wan1_ipaddr)" ] && echo -e "${BOLD}IP Address: ${NOCOLOR}${BLUE}"$(nvram get wan1_ipaddr)"${NOCOLOR}"
                        [ ! -z "$(nvram get wan1_gateway)" ] && echo -e "${BOLD}Gateway: ${NOCOLOR}${BLUE}"$(nvram get wan1_gateway)"${NOCOLOR}"
                        [ ! -z "$(nvram get wan1_gw_ifname)" ] && echo -e "${BOLD}Interface: ${NOCOLOR}${BLUE}"$(nvram get wan1_gw_ifname)"${NOCOLOR}"
                        printf "\n"
                        printf "${BOLD}Active DNS Servers:${NOCOLOR}\n"
                        ACTIVEDNSSERVERS="$(cat $DNSRESOLVFILE | awk '{print $2}')"
                        for ACTIVEDNSSERVER in ${ACTIVEDNSSERVERS};do
                          echo -e "${BLUE}$ACTIVEDNSSERVER${NOCOLOR}"
                        done
		;;
		'2')
			curl "$README" || echo -e "${RED}***Unable to access Readme***${NOCOLOR}"
		;;
		'3')
			mode="install"
			install
		;;
		'4')
			mode="uninstall"
			uninstall
		;;
		'5')
                        [ ! -f "$CONFIGFILE" ] && echo -e "${RED}WAN Failover currently has no configuration file present{$NOCOLOR}"
                        [ -f "$CONFIGFILE" ] && { setvariables || return ;}
                        printf "\n  ${BOLD}Failover Monitoring Settings:${NOCOLOR}\n"
                        printf "  (1)  Configure WAN0 Target           WAN0 Target: ${BLUE}$WAN0TARGET${NOCOLOR}\n"
                        printf "  (2)  Configure WAN1 Target           WAN1 Target: ${BLUE}$WAN1TARGET${NOCOLOR}\n"
                        printf "  (3)  Configure Ping Count            Ping Count: ${BLUE}$PINGCOUNT${NOCOLOR}\n"
                        printf "  (4)  Configure Ping Timeout          Ping Timeout: ${BLUE}$PINGTIMEOUT${NOCOLOR}\n"
                        printf "\n  ${BOLD}QoS Settings:${NOCOLOR}\n"
                        printf "  (5)  Configure WAN0                  WAN0 QoS: " && { [[ "$WAN0_QOS_ENABLE" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "  (6)  Configure WAN1                  WAN1 QoS: " && { [[ "$WAN1_QOS_ENABLE" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "\n  ${BOLD}Optional Settings:${NOCOLOR}\n"
                        printf "  (7)  Configure Packet Loss Logging   Packet Loss Logging: " && { [[ "$PACKETLOSSLOGGING" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "  (8)  Configure Boot Delay Timer      Boot Delay Timer: ${BLUE}$BOOTDELAYTIMER Seconds${NOCOLOR}\n"
                        printf "  (9)  Configure Email Notifications   Email Notifications: " && { [[ "$SENDEMAIL" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "  (10) Configure WAN0 Packet Size      WAN0 Packet Size: ${BLUE}$WAN0PACKETSIZE Bytes${NOCOLOR}\n"
                        printf "  (11) Configure WAN1 Packet Size      WAN1 Packet Size: ${BLUE}$WAN1PACKETSIZE Bytes${NOCOLOR}\n"
                        printf "  (12) Configure NVRAM Checks          NVRAM Checks: " && { [[ "$CHECKNVRAM" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "  (13) Configure Dev Mode              Dev Mode: " && { [[ "$DEVMODE" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "Disabled" ;} && printf "\n"
                        printf "  (14) Configure Custom Log Path       Custom Log Path: " && { [ ! -z "$CUSTOMLOGPATH" ] && printf "${BLUE}$CUSTOMLOGPATH${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "\n  ${BOLD}Advanced Settings:${NOCOLOR}  ${RED}***Recommended to leave default unless necessary to change***${NOCOLOR}\n"
                        printf "  (15) Configure WAN0 Route Table      WAN0 Route Table: ${BLUE}$WAN0ROUTETABLE${NOCOLOR}\n"
                        printf "  (16) Configure WAN1 Route Table      WAN1 Route Table: ${BLUE}$WAN1ROUTETABLE${NOCOLOR}\n"
                        printf "  (17) Configure WAN0 Target Priority  WAN0 Target Priority: ${BLUE}$WAN0TARGETRULEPRIORITY${NOCOLOR}\n"
                        printf "  (18) Configure WAN1 Target Priority  WAN1 Target Priority: ${BLUE}$WAN1TARGETRULEPRIORITY${NOCOLOR}\n"
                        printf "  (19) Configure Recursive Ping Check  Recursive Ping Check: ${BLUE}$RECURSIVEPINGCHECK${NOCOLOR}\n"
                        printf "  (20) Configure WAN Disabled Timer    WAN Disabled Timer: ${BLUE}$WANDISABLEDSLEEPTIMER Seconds${NOCOLOR}\n"
                        printf "  (21) Configure Email Boot Delay      Email Boot Delay: ${BLUE}$SKIPEMAILSYSTEMUPTIME Seconds${NOCOLOR}\n"
                        printf "  (22) Configure Email Timeout         Email Timeout: ${BLUE}$EMAILTIMEOUT Seconds${NOCOLOR}\n"
                        printf "  (23) Configure Cron Job              Cron Job: " && { [[ "$SCHEDULECRONJOB" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "Disabled" ;} && printf "\n"
                        printf "\n  ${BOLD}Load Balance Mode Settings:${NOCOLOR}\n"
                        printf "  (24) Configure LB Rule Priority      Load Balance Rule Priority: ${BLUE}$LBRULEPRIORITY${NOCOLOR}\n"
                        printf "  (25) Configure OpenVPN Split Tunnel  OpenVPN Split Tunneling: " && { [[ "$OVPNSPLITTUNNEL" == "1" ]] && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        printf "  (26) Configure WAN0 OVPN Priority    WAN0 OVPN Priority: ${BLUE}$OVPNWAN0PRIORITY${NOCOLOR}\n"
                        printf "  (27) Configure WAN1 OVPN Priority    WAN1 OVPN Priority: ${BLUE}$OVPNWAN1PRIORITY${NOCOLOR}\n"
                        printf "  (28) Configure WAN0 FWMark           WAN0 FWMark: ${BLUE}$WAN0MARK${NOCOLOR}\n"
                        printf "  (29) Configure WAN1 FWMark           WAN1 FWMark: ${BLUE}$WAN1MARK${NOCOLOR}\n"
                        printf "  (30) Configure WAN0 Mask             WAN0 Mask: ${BLUE}$WAN0MASK${NOCOLOR}\n"
                        printf "  (31) Configure WAN1 Mask             WAN1 Mask: ${BLUE}$WAN1MASK${NOCOLOR}\n"

	                printf "\n  (e)  Main Menu                       Return to Main Menu\n"
                        printf "\nMake a selection: "

                        NEWVARIABLES=${NEWVARIABLES:=}
                        RESTARTREQUIRED=${RESTARTREQUIRED:=0}
	                read -r configinput
	                case "${configinput}" in
		                 '1')      # WAN0TARGET
                                           while true >/dev/null 2>&1;do  
                                           read -p "Configure WAN0 Target IP Address - Will be routed via "$(nvram get wan0_gateway)" dev "$(nvram get wan0_gw_ifname)": " ip
                                           if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null 2>&1;then
                                             for i in 1 2 3 4;do
                                               if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Address: "$ip" is an Invalid IP Address"
                                                 break 1
                                               elif [[ "$(nvram get wan0_gateway)" == "$ip" ]] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is the WAN0 Gateway IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "${0##*/}" "WAN0 Target IP Address: "$ip" is WAN0 Gateway IP Address"
                                                 break 1
                                               else
                                                 SETWAN0TARGET=$ip
                                                 logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Address: "$ip""
                                                 break 2
                                               fi
                                             done
                                           else  
                                             echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                             logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Address: "$ip" is an Invalid IP Address"
                                           fi
                                         done
                                         NEWVARIABLES="${NEWVARIABLES} WAN0TARGET=|$SETWAN0TARGET"
                                         [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '2')      # WAN1TARGET
                                           while true >/dev/null 2>&1;do  
                                           read -p "Configure WAN1 Target IP Address - Will be routed via "$(nvram get wan1_gateway)" dev "$(nvram get wan1_gw_ifname)": " ip
                                           if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null 2>&1;then
                                             for i in 1 2 3 4;do
                                               if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Address: "$ip" is an Invalid IP Address"
                                                 break 1
                                               elif [[ "$(nvram get wan1_gateway)" == "$ip" ]] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is the WAN1 Gateway IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "${0##*/}" "WAN1 Target IP Address: "$ip" is WAN0 Gateway IP Address"
                                                 break 1
                                               else
                                                 SETWAN1TARGET=$ip
                                                 logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Address: "$ip""
                                                 break 2
                                               fi
                                             done
                                           else  
                                             echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                             logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Address: "$ip" is an Invalid IP Address"
                                           fi
                                         done
                                         NEWVARIABLES="${NEWVARIABLES} WAN1TARGET=|$SETWAN1TARGET"
                                         [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '3')      # PINGCOUNT
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Ping Count - This is how many consecutive times a ping will fail before a WAN connection is considered disconnected: " value
                                             case $value in
                                               [0123456789]* ) SETPINGCOUNT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter a valid number***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGCOUNT=|$SETPINGCOUNT"
                                         [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '4')      # PINGTIMEOUT
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Ping Timeout - Value is in seconds: " value
                                             case $value in
                                               [0123456789]* ) SETPINGTIMEOUT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGTIMEOUT=|$SETPINGTIMEOUT"
                                         [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '5')      # WAN0_QOS_ENABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable QoS for WAN0? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN0_QOS_ENABLE=1;;
                                               [Nn]* ) SETWAN0_QOS_ENABLE=0;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             [[ "$SETWAN0_QOS_ENABLE" == "0" ]] && { SETWAN0_QOS_IBW=0 ; SETWAN0_QOS_OBW=0 ;} && break 1
                                             read -p "Do you want to use Automatic QoS Settings for WAN0? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN0_QOS_IBW=0;SETWAN0_QOS_OBW=0; break 1;;
                                               [Nn]* ) ;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             read -p "Configure WAN0 QoS Download Bandwidth - Value is in Mbps: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0_QOS_IBW=$(($value*1024));;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
                                             esac
                                             read -p "Configure WAN0 QoS Upload Bandwidth - Value is in Mbps: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0_QOS_OBW=$(($value*1024)); break 1;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_ENABLE=|$SETWAN0_QOS_ENABLE WAN0_QOS_IBW=|$SETWAN0_QOS_IBW WAN0_QOS_OBW=|$SETWAN0_QOS_OBW"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '6')      # WAN1_QOS_ENABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable QoS for WAN1? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN1_QOS_ENABLE=1;;
                                               [Nn]* ) SETWAN1_QOS_ENABLE=0;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             [[ "$SETWAN1_QOS_ENABLE" == "0" ]] && { SETWAN1_QOS_IBW=0 ; SETWAN1_QOS_OBW=0 ;} && break 1
                                             read -p "Do you want to use Automatic QoS Settings for WAN1? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN1_QOS_IBW=0;SETWAN1_QOS_OBW=0; break 1;;
                                               [Nn]* ) ;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             read -p "Configure WAN1 QoS Download Bandwidth - Value is in Mbps: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1_QOS_IBW=$(($value*1024));;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
                                             esac
                                             read -p "Configure WAN1 QoS Upload Bandwidth - Value is in Mbps: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1_QOS_OBW=$(($value*1024)); break 1;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_ENABLE=|$SETWAN1_QOS_ENABLE WAN1_QOS_IBW=|$SETWAN1_QOS_IBW WAN1_QOS_OBW=|$SETWAN1_QOS_OBW"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '7')      # PACKETLOSSLOGGING

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Packet Loss Logging? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETPACKETLOSSLOGGING=1; break;;
                                               [Nn]* ) SETPACKETLOSSLOGGING=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} PACKETLOSSLOGGING=|$SETPACKETLOSSLOGGING"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '8')      # BOOTDELAYTIMER

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Boot Delay Timer - This will delay the script from executing until System Uptime reaches this time (seconds): " value
                                             case $value in
                                               [0123456789]* ) SETBOOTDELAYTIMER=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} BOOTDELAYTIMER=|$SETBOOTDELAYTIMER"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '9')      # SENDEMAIL

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Email Notifications? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETSENDEMAIL=1; break;;
                                               [Nn]* ) SETSENDEMAIL=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SENDEMAIL=|$SETSENDEMAIL"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '10')      # WAN0PACKETSIZE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN0 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0PACKETSIZE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0PACKETSIZE=|$SETWAN0PACKETSIZE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '11')      # WAN1PACKETSIZE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN1 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1PACKETSIZE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1PACKETSIZE=|$SETWAN1PACKETSIZE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '12')      # CHECKNVRAM

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable NVRAM Checks? This defines if the Script is set to perform NVRAM checks before peforming key functions: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETCHECKNVRAM=1; break;;
                                               [Nn]* ) SETCHECKNVRAM=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} CHECKNVRAM=|$SETCHECKNVRAM"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '13')      # DEVMODE

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Developer Mode? This defines if the Script is set to Developer Mode where updates will apply beta releases: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETDEVMODE=1; break;;
                                               [Nn]* ) SETDEVMODE=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} DEVMODE=|$SETDEVMODE"
                                 ;;
		                 '14')      # CUSTOMLOGPATH

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Custom Log Path - This defines a Custom System Log path for Monitor/Capture Mode: " value
                                             case $value in
                                               [:.-_/0123456789abcdefghijklmnopqstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]* ) SETCUSTOMLOGPATH=$value; break;;
                                               "" ) SETCUSTOMLOGPATH=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} CUSTOMLOGPATH=|$SETCUSTOMLOGPATH"
                                 ;;
		                 '15')      # WAN0ROUTETABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Route Table - This defines the Routing Table for WAN0, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0ROUTETABLE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0ROUTETABLE=|$SETWAN0ROUTETABLE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '16')      # WAN1ROUTETABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Route Table - This defines the Routing Table for WAN1, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1ROUTETABLE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1ROUTETABLE=|$SETWAN1ROUTETABLE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '17')      # WAN0TARGETRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Target Rule Priority - This defines the IP Rule Priority for the WAN0 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0TARGETRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0TARGETRULEPRIORITY=|$SETWAN0TARGETRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '18')      # WAN1TARGETRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Target Rule Priority - This defines the IP Rule Priority for the WAN1 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1TARGETRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1TARGETRULEPRIORITY=|$SETWAN1TARGETRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '19')      # RECURSIVEPINGCHECK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Recursive Ping Check - This defines how many times a WAN Interface has to fail target pings to be considered failed (Ping Count x RECURSIVEPINGCHECK), this setting is for circumstances where ICMP Echo / Response can be disrupted by ISP DDoS Prevention or other factors.  It is recommended to leave this setting default: " value
                                             case $value in
                                               [0123456789]* ) SETRECURSIVEPINGCHECK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} RECURSIVEPINGCHECK=|$SETRECURSIVEPINGCHECK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '20')      # WANDISABLEDSLEEPTIMER

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN Disabled Sleep Timer - This is how many seconds the WAN Failover pauses and checks again if Dual WAN, Failover/Load Balance Mode, or WAN links are disabled/disconnected: " value
                                             case $value in
                                               [0123456789]* ) SETWANDISABLEDSLEEPTIMER=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WANDISABLEDSLEEPTIMER=|$SETWANDISABLEDSLEEPTIMER"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '21')      # SKIPEMAILSYSTEMUPTIME

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Email Boot Delay Timer - This will delay sending emails while System Uptime is less than this time: " value
                                             case $value in
                                               [0123456789]* ) SETSKIPEMAILSYSTEMUPTIME=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SKIPEMAILSYSTEMUPTIME=|$SETSKIPEMAILSYSTEMUPTIME"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '22')      # EMAILTIMEOUT

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Email Timeout - This defines the timeout for sending an email after a Failover event: " value
                                             case $value in
                                               [0123456789]* ) SETEMAILTIMEOUT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} EMAILTIMEOUT=|$SETEMAILTIMEOUT"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '23')      # SCHEDULECRONJOB

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Cron Job? This defines if the script will create the Cron Job: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SCHEDULECRONJOB=1; break;;
                                               [Nn]* ) SCHEDULECRONJOB=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SCHEDULECRONJOB=|$SCHEDULECRONJOB"
                                 ;;
		                 '24')      # LBRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Load Balance Rule Priority - This defines the IP Rule priority for Load Balance Mode, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETLBRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} LBRULEPRIORITY=|$SETLBRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '25')      # OVPNSPLITTUNNEL

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable OpenVPN Split Tunneling? This will enable or disable OpenVPN Split Tunneling while in Load Balance Mode: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETOVPNSPLITTUNNEL=1; break;;
                                               [Nn]* ) SETOVPNSPLITTUNNEL=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNSPLITTUNNEL=|$SETOVPNSPLITTUNNEL"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '26')      # OVPNWAN0PRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure OpenVPN WAN0 Priority - This defines the OpenVPN Tunnel Priority for WAN0 if OVPNSPLITTUNNEL is Disabled: " value
                                             case $value in
                                               [0123456789]* ) SETOVPNWAN0PRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNWAN0PRIORITY=|$SETOVPNWAN0PRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '27')      # OVPNWAN1PRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure OpenVPN WAN1 Priority - This defines the OpenVPN Tunnel Priority for WAN1 if OVPNSPLITTUNNEL is Disabled: " value
                                             case $value in
                                               [0123456789]* ) SETOVPNWAN1PRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNWAN1PRIORITY=|$SETOVPNWAN1PRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '28')      # WAN0MARK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 FWMark - This defines the WAN0 FWMark for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN0MARK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0MARK=|$SETWAN0MARK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '29')      # WAN1MARK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 FWMark - This defines the WAN1 FWMark for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN1MARK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1MARK=|$SETWAN1MARK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '30')      # WAN0MASK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Mask - This defines the WAN0 Mask for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN0MASK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0MASK=|$SETWAN0MASK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;
		                 '31')      # WAN1MASK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Mask - This defines the WAN1 Mask for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN1MASK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1MASK=|$SETWAN1MASK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] && RESTARTREQUIRED=1
                                 ;;


	      	                 'e'|'E'|'exit'|'menu')
                                 clear
		                 menu
                                 break
		                 ;;


                        esac

                        # Configure Changed Setting in Configuration File
                        NEWVARIABLES=${NEWVARIABLES:=}
                        if [ ! -z "$NEWVARIABLES" ] >/dev/null 2>&1;then
                          for NEWVARIABLE in ${NEWVARIABLES};do
                            if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
                              sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
                            elif [ ! -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
                            elif [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" == "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              [ ! -z "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ] && sed -i '/CUSTOMLOGPATH=/d' $CONFIGFILE
                              echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')" >> $CONFIGFILE
                            fi
                          done
                        fi
                        [ ! -z "$NEWVARIABLES" ] && NEWVARIABLE=""
                        [[ "$RESTARTREQUIRED" == "1" ]] && echo -e "${RED}This change will require WAN Failover to restart to take effect...${NOCOLOR}" && RESTARTREQUIRED="0"
	                PressEnter
	                menu
		;;
		'6')
			mode="update"
                        update
		;;
		'7')
			mode="cron"
                        cronjob
		;;
		'8')
			mode="manual"
                        scriptmode
		;;
		'9')
			mode="initiate"
                        scriptmode
		;;
		'10')
			mode="monitor"
                        echo -e ""${BOLD}"${GREEN}$ALIAS - Monitor Mode${NOCOLOR}"
                        trap 'menu' EXIT HUP INT QUIT TERM
			monitor
		;;
		'11')
			mode="capture"
                        echo -e ""${BOLD}"${GREEN}$ALIAS - Capture Mode${NOCOLOR}"
                        trap 'menu' EXIT HUP INT QUIT TERM
			monitor
		;;
		'12')
			mode="restart"
                        killscript
		;;
		'13')
			mode="kill"
                        killscript
		;;
		'14')
			mode="switchwan"
                        scriptmode
		;;
		'e'|'E'|'exit')
			exit 0
		;;
		*)
			Red "$input is not a valid option!"
		;;
	esac
	PressEnter
	menu

}

PressEnter(){
	printf "\n"
	while true; do
		printf "Press Enter to continue..."
		read -r "key"
		case "${key}" in
			*)
				break
			;;
		esac
	done
        [[ "$mode" != "menu" ]] && mode=menu
	return 0
}

systemcheck ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: systemcheck"

# Get Log Level
logger -p 6 -t "${0##*/}" "Debug - Log Level: "$(nvram get log_level)""

# Get PID
logger -p 5 -t "${0##*/}" "System Check - Process ID: "$$""

# Check NVRAM
CHECKNVRAM=${CHECKNVRAM:=1}
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

# Check System Binaries Path
systembinaries || return

# Script Version Logging
logger -p 5 -t "${0##*/}" "System Check - Version: "$VERSION""

# Supported Firmware Versions
FWVERSIONS='
386.5
386.7
386.9
388.1
'

# Firmware Version Check
logger -p 6 -t "${0##*/}" "Debug - Firmware: "$(nvram get buildno)""
for FWVERSION in ${FWVERSIONS};do
  if [[ "$(nvram get 3rd-party)" == "merlin" ]] && [[ "$(nvram get buildno)" == "$FWVERSION" ]] >/dev/null 2>&1;then
    break
  elif [[ "$(nvram get 3rd-party)" == "merlin" ]] && [ ! -z "$(echo "${FWVERSIONS}" | grep -w "$(nvram get buildno)")" ] >/dev/null 2>&1;then
    continue
  else
    logger -p 3 -st "${0##*/}" "System Check - ***"$(nvram get buildno)" is not supported, issues may occur from running this version***"
  fi
done

# IPRoute Version Check
logger -p 5 -t "${0##*/}" "System Check - IPRoute Version: "$(ip -V | awk -F "-" '{print $2}')""

# JFFS Custom Scripts Enabled Check
logger -p 6 -t "${0##*/}" "Debug - JFFS custom scripts and configs: "$(nvram get jffs2_scripts)""
if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null 2>&1;then
  logger -p 3 -st "${0##*/}" "System Check - ***JFFS custom scripts and configs not Enabled***"
fi

# Check Alias
logger -p 6 -t "${0##*/}" "Debug - Checking Alias in /jffs/configs/profile.add"
if [ ! -f "/jffs/configs/profile.add" ] >/dev/null 2>&1;then
  logger -p 5 -st "${0##*/}" "System Check - Creating /jffs/configs/profile.add"
  touch -a /jffs/configs/profile.add \
  && chmod 666 /jffs/configs/profile.add \
  && logger -p 4 -st "${0##*/}" "System Check - Created /jffs/configs/profile.add" \
  || logger -p 2 -st "${0##*/}" "System Check - ***Error*** Unable to create /jffs/configs/profile.add"
fi
if [ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
  logger -p 5 -st "${0##*/}" "System Check - Creating Alias for "$0" as wan-failover"
  echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add \
  && source /jffs/configs/profile.add \
  && logger -p 4 -st "${0##*/}" "System Check - Created Alias for "$0" as wan-failover" \
  || logger -p 2 -st "${0##*/}" "System Check - ***Error*** Unable to create Alias for "$0" as wan-failover"
fi

# Check Configuration File
logger -p 6 -t "${0##*/}" "Debug - Checking for Configuration File: "$CONFIGFILE""
if [ ! -f "$CONFIGFILE" ] >/dev/null 2>&1;then
  echo -e ""${BOLD}"${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  logger -p 2 -t "${0##*/}" "System Check - ***No Configuration File Detected - Run Install Mode***"
  exit
fi

# Turn off email notification for initial load of WAN Failover
email=${email:=0}
return
}

# Set Script to use System Binaries
systembinaries ()
{
# Check System Binaries Path
if [[ "$(echo $PATH | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting System Binaries Path"
  export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
  logger -p 6 -t "${0##*/}" "Debug - PATH: "$PATH""g
fi
}

# Install
install ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: Install"
if [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
  read -n 1 -s -r -p "Press any key to continue to install..."
fi

if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null 2>&1;then
  if [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
    # Check if JFFS Custom Scripts is enabled during installation
    if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null 2>&1;then
      echo -e "${RED}Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}"
      logger -p 3 -t "${0##*/}" "Install - Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled"
    else
      echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
    fi
  fi

  # Check for Config File
  if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null 2>&1;then
    echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Creating $CONFIGFILE"
    if [ ! -f $CONFIGFILE ] >/dev/null 2>&1;then
      touch -a $CONFIGFILE
      chmod 666 $CONFIGFILE
      echo -e "${GREEN}$CONFIGFILE created.${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - $CONFIGFILE created"
    else
      echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}"
      logger -p 4 -t "${0##*/}" "Install - $CONFIGFILE already exists"
    fi
  fi

  # Prompt to ask confirmation for reconfiguration
  if [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
    break
  elif [[ "${mode}" == "config" ]] && [ -f $CONFIGFILE ] >/dev/null 2>&1;then
    while [[ "${mode}" == "config" ]] >/dev/null 2>&1;do
      read -p "Do you want to reconfigure WAN Failover? ***Enter Y for Yes or N for No***" yn
      case $yn in
        [Yy]* ) break;;
        [Nn]* ) return;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
    done
    . $CONFIGFILE
  elif [[ "${mode}" == "config" ]] && [ ! -f $CONFIGFILE ] >/dev/null 2>&1;then
    echo -e "${RED}$CONFIGFILE doesn't exist, please run Install Mode...${NOCOLOR}"
    logger -p 3 -t "${0##*/}" "Configuration - $CONFIGFILE doesn't exist, please run Install Mode"
  fi

  # Restart WAN0 if no IP Address or Gateway IP is Assigned
  if { { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_ipaddr)" ] ;} \
  || { [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_gateway)" ] ;} ;} >/dev/null 2>&1;then
    service "restart_wan_if 0"
    while [[ "$(nvram get wan0_state_t)" == "6" ]] && [[ "$(nvram get wan0_state_t)" != "2" ]] >/dev/null 2>&1;do
      sleep 1
    done
  fi

  # Restart WAN1 if no IP Address or Gateway IP is Assigned
  if { { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_ipaddr)" ] ;} \
  || { [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_gateway)" ] ;} ;} >/dev/null 2>&1;then
    service "restart_wan_if 1"
    while [[ "$(nvram get wan1_state_t)" == "6" ]] && [[ "$(nvram get wan1_state_t)" != "2" ]] >/dev/null 2>&1;do
      sleep 1
    done
  fi

  # User Input for Custom Variables
  echo "Setting Custom Variables..."

  # Configure WAN Target IP Addresses
  for WANPREFIX in ${WANPREFIXES};do
    echo -e "${YELLOW}***"${WANPREFIX}" Target IP Addresses will have an IP Rule created to route traffic from the Router to the IP via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"***${NOCOLOR}"
    # Configure WAN Target IP Addresses
    while true >/dev/null 2>&1;do  
      read -p "Configure "${WANPREFIX}" Target IP Address - Will be routed via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)": " ip
      if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null 2>&1;then
        for i in 1 2 3 4;do
          if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null 2>&1;then
            echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
            logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Address: "$ip" is an Invalid IP Address"
            break 1
          elif [[ "$(nvram get ${WANPREFIX}_gateway)" == "$ip" ]] >/dev/null 2>&1;then
            echo -e "${RED}***"$ip" is the "${WANPREFIX}" Gateway IP Address***${NOCOLOR}"
            logger -p 6 -t "${0##*/}" ""${WANPREFIX}" Target IP Address: "$ip" is "${WANPREFIX}" Gateway IP Address"
            break 1
          else
            [[ "${WANPREFIX}" == "wan0" ]] && SETWAN0TARGET=$ip
            [[ "${WANPREFIX}" == "wan1" ]] && SETWAN1TARGET=$ip
            logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Address: "$ip""
            break 2
          fi
        done
      else  
        echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Address: "$ip" is an Invalid IP Address"
        continue
      fi
    done
  done

  # Configure Ping Count
  while true >/dev/null 2>&1;do  
    read -p "Configure Ping Count - This is how many consecutive times a ping will fail before a WAN connection is considered disconnected: " value
    case $value in
      [0123456789]* ) SETPINGCOUNT=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter a valid number***${NOCOLOR}"
    esac
  done
  # Configure Ping Timeout
  while true >/dev/null 2>&1;do  
    read -p "Configure Ping Timeout - Value is in seconds: " value
    case $value in
      [0123456789]* ) SETPINGTIMEOUT=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done

  # Configure QoS Settings
  for WANPREFIX in ${WANPREFIXES};do 
    # Configure WAN QoS Download Bandwidth
    while true >/dev/null 2>&1;do
      read -p "Do you want to enable QoS for "${WANPREFIX}"? ***Enter Y for Yes or N for No***" yn
      case $yn in
        [Yy]* ) SETWAN_QOS_ENABLE=1;;
        [Nn]* ) SETWAN_QOS_ENABLE=0;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
      [[ "$SETWAN_QOS_ENABLE" == "0" ]] && { SETWAN_QOS_IBW=0 ; SETWAN_QOS_OBW=0 ;} && break 1
      read -p "Do you want to use Automatic QoS Settings for "${WANPREFIX}"? ***Enter Y for Yes or N for No***" yn
      case $yn in
        [Yy]* ) SETWAN_QOS_IBW=0;SETWAN_QOS_OBW=0; break 1;;
        [Nn]* ) ;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
      read -p "Configure "${WANPREFIX}" QoS Download Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN_QOS_IBW=$(($value*1024));;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
      read -p "Configure "${WANPREFIX}" QoS Upload Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN_QOS_OBW=$(($value*1024)); break 1;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
    done
    [[ "${WANPREFIX}" == "wan0" ]] && { SETWAN0_QOS_ENABLE=$SETWAN_QOS_ENABLE ; SETWAN0_QOS_IBW=$SETWAN_QOS_IBW ; SETWAN0_QOS_OBW=$SETWAN_QOS_OBW ;}
    [[ "${WANPREFIX}" == "wan1" ]] && { SETWAN1_QOS_ENABLE=$SETWAN_QOS_ENABLE ; SETWAN1_QOS_IBW=$SETWAN_QOS_IBW ; SETWAN1_QOS_OBW=$SETWAN_QOS_OBW ;}
  done

# Create Array for Custom Variables
NEWVARIABLES='
WAN0TARGET=|'$SETWAN0TARGET'
WAN1TARGET=|'$SETWAN1TARGET'
PINGCOUNT=|'$SETPINGCOUNT'
PINGTIMEOUT=|'$SETPINGTIMEOUT'
WAN0_QOS_ENABLE=|'$SETWAN0_QOS_ENABLE'
WAN0_QOS_IBW=|'$SETWAN0_QOS_IBW'
WAN0_QOS_OBW=|'$SETWAN0_QOS_OBW'
WAN1_QOS_ENABLE=|'$SETWAN1_QOS_ENABLE'
WAN1_QOS_IBW=|'$SETWAN1_QOS_IBW'
WAN1_QOS_OBW=|'$SETWAN1_QOS_OBW'
'
  # Adding Custom Variables to Config File
  echo -e "${BLUE}Adding Custom Settings to $CONFIGFILE...${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Install - Adding Custom Settings to $CONFIGFILE"
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null 2>&1;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    else
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    fi
  done
  echo -e "${GREEN}Custom Variables added to $CONFIGFILE.${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Install - Custom Variables added to $CONFIGFILE"

  if [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
    # Create Wan-Event if it doesn't exist
    echo -e "${BLUE}Creating Wan-Event script...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Creating Wan-Event script"
    if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null 2>&1;then
      touch -a /jffs/scripts/wan-event
      chmod 755 /jffs/scripts/wan-event
      echo "#!/bin/sh" >> /jffs/scripts/wan-event
      echo -e "${GREEN}Wan-Event script has been created.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Wan-Event script has been created"
    else
      echo -e "${YELLOW}Wan-Event script already exists...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Wan-Event script already exists"
    fi

    # Add Script to Wan-event
    if [ ! -z "$(cat /jffs/scripts/wan-event | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then 
      echo -e "${YELLOW}${0##*/} already added to Wan-Event...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - ${0##*/} already added to Wan-Event"
    else
      cmdline="sh $0 cron"
      echo -e "${BLUE}Adding ${0##*/} to Wan-Event...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Adding ${0##*/} to Wan-Event"
      echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event
      echo -e "${GREEN}${0##*/} added to Wan-Event.${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - ${0##*/} added to Wan-Event"
    fi

    # Create /jffs/configs/profile.add if it doesn't exist
    echo -e "${BLUE}Creating /jffs/configs/profile.add...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Creating /jffs/configs/profile.add"
    if [ ! -f "/jffs/configs/profile.add" ] >/dev/null 2>&1;then
      touch -a /jffs/configs/profile.add
      chmod 666 /jffs/configs/profile.add
      echo -e "${GREEN}/jffs/configs/profile.add has been created.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - /jffs/configs/profile.add has been created"
    else
      echo -e "${YELLOW}/jffs/configs/profile.add already exists...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - /jffs/configs/profile.add already exists"
    fi

    # Create Alias
    if [ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
      echo -e "${BLUE}${0##*/} - Install: Creating Alias for "$0" as wan-failover...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Creating Alias for "$0" as wan-failover"
      echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add
      source /jffs/configs/profile.add
      echo -e "${GREEN}${0##*/} - Install: Created Alias for "$0" as wan-failover...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Created Alias for "$0" as wan-failover"
    fi

    # Create Initial Cron Jobs
    cronjob &
  fi
  # Kill current instance of script to allow new configuration to take place.
  if [[ "${mode}" == "config" ]] >/dev/null 2>&1;then
    cleanup
    killscript
  fi
fi
return
}

# Uninstall
uninstall ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: Uninstall"
if [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  $(cronjob >/dev/null &)

  # Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Uninstall - Deleting $CONFIGFILE"
  if [ -f $CONFIGFILE ] >/dev/null 2>&1;then
    # Load Variables from Configuration first for Cleanup
    . $CONFIGFILE
    rm -f $CONFIGFILE
    echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $CONFIGFILE deleted"
  else
    echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE doesn't exist.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $CONFIGFILE doesn't exist"
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null 2>&1;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removed Cron Job from Wan-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Wan-Event.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Wan-Event"
  fi

  # Remove Alias
  if [ ! -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Alias for "$0" as wan-failover...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removing Alias for "$0" as wan-failover"
    sed -i '\~# Wan-Failover~d' /jffs/configs/profile.add
    source /jffs/configs/profile.add
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Alias for "$0" as wan-failover...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removed Alias for "$0" as wan-failover"
  fi

  # Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $0...${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Uninstall - Deleting $0"
  if [ -f $0 ] >/dev/null 2>&1;then
    rm -f $0
    echo -e "${GREEN}${0##*/} - Uninstall: $0 deleted.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $0 deleted"
  else
    echo -e "${RED}${0##*/} - Uninstall: $0 doesn't exist.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $0 doesn't exist"
  fi

  # Cleanup
  cleanup || continue

  # Kill Running Processes
  echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
  logger -p 0 -t "${0##*/}" "Uninstall - Killing ${0##*/}"
  sleep 3 && killall ${0##*/}
fi
return
}

# Cleanup
cleanup ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: cleanup"

for WANPREFIX in ${WANPREFIXES};do
  logger -p 6 -t "${0##*/}" "Debug - Setting parameters for "${WANPREFIX}""

  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
    TARGET="$WAN0TARGET"
    TABLE="$WAN0ROUTETABLE"
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
    TARGET="$WAN1TARGET"
    TABLE="$WAN1ROUTETABLE"
  fi

  # Delete WAN IP Rule
  logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for IP Rule to "$TARGET""
  if [ ! -z "$(ip rule list from all to "$TARGET" lookup "$TABLE")" ] >/dev/null 2>&1;then
    logger -p 5 -t "${0##*/}" "Cleanup - Deleting IP Rule for "$TARGET" to monitor "${WANPREFIX}""
    until [ -z "$(ip rule list from all to "$TARGET" lookup "$TABLE")" ] >/dev/null 2>&1;do
      ip rule del from all to $TARGET lookup $TABLE \
      && logger -p 4 -t "${0##*/}" "Cleanup - Deleted IP Rule for "$TARGET" to monitor "${WANPREFIX}"" \
      || logger -p 2 -t "${0##*/}" "Cleanup - ***Error*** Unable to delete IP Rule for "$TARGET" to monitor "${WANPREFIX}""
    done
  fi

  # Delete WAN Route for Target IP
  logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
  if [ ! -z "$(ip route list "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)")" ] >/dev/null 2>&1;then
    logger -p 5 -t "${0##*/}" "Cleanup - Deleting route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
    ip route del $TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) \
    && logger -p 4 -t "${0##*/}" "Cleanup - Deleted route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"" \
    || logger -p 2 -t "${0##*/}" "Cleanup - ***Error*** Unable to delete route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
  fi

  # Delete Packet Loss Temp File
  logger -p 6 -t "${0##*/}" "Debug - Checking for /tmp/"${WANPREFIX}"packetloss.tmp"
  if [ -f "/tmp/${WANPREFIX}packetloss.tmp" ] >/dev/null 2>&1;then
    logger -p 5 -t "${0##*/}" "Cleanup - Deleting /tmp/"${WANPREFIX}"packetloss.tmp"
    rm -f /tmp/"${WANPREFIX}"packetloss.tmp \
    && logger -p 4 -t "${0##*/}" "Cleanup - Deleted /tmp/"${WANPREFIX}"packetloss.tmp" \
    || logger -p 2 -t "${0##*/}" "Cleanup - ***Error*** Unable to delete /tmp/"${WANPREFIX}"packetloss.tmp"
  fi
done

# Remove Lock File
logger -p 6 -t "${0##*/}" "Debug - Checking for Lock File: "$LOCKFILE""
if [ -f "$LOCKFILE" ] >/dev/null 2>&1;then
  logger -p 5 -t "${0##*/}" "Cleanup - Deleting "$LOCKFILE""
  rm -f "$LOCKFILE" \
  && logger -p 4 -t "${0##*/}" "Cleanup - Deleted "$LOCKFILE"" \
  || logger -p 2 -t "${0##*/}" "Cleanup - ***Error*** Unable to delete "$LOCKFILE""
fi
return
}

# Kill Script
killscript ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: killscript"

if [[ "${mode}" == "restart" ]] || [[ "${mode}" == "update" ]] || [[ "${mode}" == "config" ]] || [[ "$[mode}" == "email" ]] >/dev/null 2>&1;then
  while [[ "${mode}" == "restart" ]] >/dev/null 2>&1;do
    read -p "Are you sure you want to restart WAN Failover? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  # Determine PIDs to kill
  logger -p 6 -t "${0##*/}" "Debug - Selecting PIDs to kill"
  PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"

  # Schedule CronJob  
  logger -p 6 -t "${0##*/}" "Debug - Calling CronJob to be rescheduled"
  $(cronjob >/dev/null &) || return

  logger -p 6 -t "${0##*/}" "Debug - ***Checking if PIDs array is null*** Process ID: "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
    # Schedule kill for Old PIDs
    logger -p 1 -st "${0##*/}" "Restart - Restarting ${0##*/} ***This can take up to approximately 1 minute***"
    logger -p 6 -t "${0##*/}" "Debug - Waiting to kill script until seconds into the minute are above 40 seconds or below 45 seconds"
    CURRENTSYSTEMUPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
    while [[ "$(date "+%S")" -lt "40" ]] || [[ "$(date "+%S")" -gt "45" ]] >/dev/null 2>&1;do
      [[ "${mode}" == "config" ]] && break 1
      [[ "${mode}" == "update" ]] && break 1
      if tty >/dev/null 2>&1;then
        WAITTIMER=$(($(awk -F "." '{print $1}' "/proc/uptime")-$CURRENTSYSTEMUPTIME))
        if [[ "$WAITTIMER" -lt "30" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${GREEN}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -lt "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${YELLOW}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -ge "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${RED}""$WAITTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    done
    # Kill PIDs
    until [ -z "$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')" ] >/dev/null 2>&1;do
      PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
      for PID in ${PIDS};do
        [ ! -z "$(ps | grep -m 1 -o "${PID}")" ] \
        && logger -p 1 -st "${0##*/}" "Restart - Killing ${0##*/} Process ID: "${PID}"" \
          && { kill -9 ${PID} \
          && { logger -p 1 -st "${0##*/}" "Restart - Killed ${0##*/} Process ID: "${PID}"" && continue ;} \
          || { [ -z "$(ps | grep -m 1 -o "${PID}")" ] && continue || logger -p 2 -st "${0##*/}" "Restart - ***Error*** Unable to kill ${0##*/} Process ID: "${PID}"" ;} ;} \
        || continue
      done
    done
    # Execute Cleanup
    . $CONFIGFILE
    cleanup || continue
  elif [ -z "$PIDS" ] >/dev/null 2>&1;then
    # Log no PIDs found and return
    logger -p 2 -st "${0##*/}" "Restart - ***${0##*/} is not running*** No Process ID Detected"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}""${RED}"***${0##*/} is not running*** No Process ID Detected"${NOCOLOR}""
      sleep 3
      printf '\033[K'
    fi
  fi

  # Check for Restart from Cron Job
  RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+120))"
  logger -p 5 -st "${0##*/}" "Restart - Waiting for ${0##*/} to restart from Cron Job"
  logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
  logger -p 6 -t "${0##*/}" "Debug - Restart Timeout is in "$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))" Seconds"
  while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] >/dev/null 2>&1;do
    PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
    if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
      break
    elif [ -z "$PIDS" ] >/dev/null 2>&1;then
      if tty >/dev/null 2>&1;then
        TIMEOUTTIMER=$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
        if [[ "$TIMEOUTTIMER" -ge "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${GREEN}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "30" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${YELLOW}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "0" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${RED}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    fi
  done
  logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"

  # Check if script restarted
  logger -p 6 -t "${0##*/}" "Debug - Checking if "${0##*/}" restarted"
  PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
  logger -p 6 -t "${0##*/}" "Debug - ***Checking if PIDs array is null*** Process ID(s): "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
    logger -p 1 -st "${0##*/}" "Restart - Successfully Restarted ${0##*/} Process ID(s): "$PIDS""
    if tty >/dev/null 2>&1;then
      printf '\033[K%b' ""${BOLD}""${GREEN}"Successfully Restarted ${0##*/} Process ID(s): "$(for PID in ${PIDS};do echo "${PID}\t";done)" "${NOCOLOR}"\r"
      sleep 10
      printf '\033[K'
    fi
  elif [ -z "$PIDS" ] >/dev/null 2>&1;then
    logger -p 1 -st "${0##*/}" "Restart - Failed to restart ${0##*/} ***Check Logs***"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}""${RED}"Failed to restart ${0##*/} ***Check Logs***"${NOCOLOR}""
      sleep 10
      printf '\033[K'
    fi
  fi
  return
elif [[ "${mode}" == "kill" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Calling CronJob to delete jobs"
  $(cronjob >/dev/null &)
  logger -p 0 -st "${0##*/}" "Kill - Killing ${0##*/}"
  killall ${0##*/}
  return
fi
return
}

# Update Script
update ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: update"

# Get Configuration Settings
. $CONFIGFILE

# Determine Production or Beta Update Channel
if [[ "$DEVMODE" == "0" ]] >/dev/null 2>&1;then
  DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
elif [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1;then
  DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover-beta.sh"
fi

# Determine if newer version is available
REMOTEVERSION="$(echo $(curl "$DOWNLOADPATH" | grep -v "grep" | grep -w "# Version:" | awk '{print $3}'))"
if [[ "$VERSION" != "$REMOTEVERSION" ]] >/dev/null 2>&1;then
  [[ "$DEVMODE" == "1" ]] && echo -e "${RED}***Dev Mode is Enabled***${NOCOLOR}"
  echo -e "${YELLOW}Script is out of date - Current Version: ${BLUE}"$VERSION"${YELLOW} Available Version: ${BLUE}"$REMOTEVERSION"${NOCOLOR}${NOCOLOR}"
  logger -p 3 -t "${0##*/}" "Script is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION""
  while true >/dev/null 2>&1;do  
    [[ "$DEVMODE" == "0" ]] && read -p "Do you want to update to the latest production version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** " yn
    [[ "$DEVMODE" == "1" ]] && read -p "Do you want to update to the latest beta version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 && killscript \
  && logger -p 4 -st "${0##*/}" "Update - ${0##*/} has been updated to version: "$REMOTEVERSION"" \
  || logger -p 2 -st "${0##*/}" "Update - ***Error*** Unable to update to version: "$REMOTEVERSION" ${0##*/}"
elif [[ "$VERSION" == "$REMOTEVERSION" ]] >/dev/null 2>&1;then
  echo -e "${GREEN}Script is up to date - Version: "$VERSION"${NOCOLOR}"
  while true >/dev/null 2>&1;do  
    read -p "Script is up to date. Do you want to reinstall "${0##*/}" Version: "$VERSION"? ***Enter Y for Yes or N for No*** " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 && killscript \
  && logger -p 4 -st "${0##*/}" "Update - ${0##*/} has reinstalled version: "$VERSION"" \
  || logger -p 2 -st "${0##*/}" "Update - ***Error*** Unable to reinstall version: "$VERSION" ${0##*/}"
fi
}

# Cronjob
cronjob ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: cronjob"

# Lock Cron Job to ensure only one instance is ran at a time
  CRONLOCKFILE="/var/lock/wan-failover-cron.lock"
  exec 101>"$CRONLOCKFILE" || return
  flock -x -n 101 && echo  || { echo -e "${RED}${0##*/} Cron Job Mode is already running...${NOCOLOR}" && return ;}
  trap 'rm -f "$CRONLOCKFILE" || return' EXIT HUP INT QUIT TERM

# Create Cron Job
if [[ "$SCHEDULECRONJOB" == "1" ]] && { [[ "${mode}" == "cron" ]] || [[ "${mode}" == "install" ]] || [[ "${mode}" == "restart" ]] || [[ "${mode}" == "update" ]] || [[ "${mode}" == "config" ]] ;} >/dev/null 2>&1;then
  if [ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    logger -p 5 -st "${0##*/}" "Cron - Creating Cron Job"
    $(cru a setup_wan_failover_run "*/1 * * * *" $0 run) \
    && logger -p 4 -st "${0##*/}" "Cron - Created Cron Job" \
    || logger -p 2 -st "${0##*/}" "Cron - ***Error*** Unable to create Cron Job"
  elif tty >/dev/null 2>&1 && [ ! -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    echo -e "${GREEN}Cron Job already scheduled...${NOCOLOR}"
  fi
# Remove Cron Job
elif [[ "$SCHEDULECRONJOB" == "0" ]] || [[ "${mode}" == "kill" ]] || [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
  if [ ! -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "Cron - Removing Cron Job"
    $(cru d setup_wan_failover_run) \
    && logger -p 3 -st "${0##*/}" "Cron - Removed Cron Job" \
    || logger -p 2 -st "${0##*/}" "Cron - ***Error*** Unable to remove Cron Job"
  elif tty >/dev/null 2>&1 && [ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    echo -e "${GREEN}Cron Job already unscheduled...${NOCOLOR}"
  fi
fi
return
}

# Monitor Logging
monitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: monitor"

# Set System Binaries
systembinaries || return

# Set Variables
setvariables || return

# Reset System Log Path being Set
systemlogset=${systemlogset:=0}
if [[ "$systemlogset" != "0" ]] >/dev/null 2>&1;then
  systemlogset=0
fi

# Check Custom Log Path is Specified
[[ "$systemlogset" == "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Checking if Custom Log Path is Specified"
if [[ "$systemlogset" == "0" ]] && [ ! -z "$CUSTOMLOGPATH" ] && [ -f "$CUSTOMLOGPATH" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Custom Log Path: "$CUSTOMLOGPATH""
  SYSLOG="$CUSTOMLOGPATH" && systemlogset=1
fi

# Check if Scribe is Installed
[[ "$systemlogset" == "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Checking if Scribe is Installed"
if [[ "$systemlogset" == "0" ]] && { [ -f "/jffs/scripts/scribe" ] && [ -e "/opt/bin/scribe" ] && [ -f "/opt/var/log/messages" ] ;} >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Scribe is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if Entware syslog-ng package is Installed
[[ "$systemlogset" == "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Checking if Entware syslog-ng package is Installed"
if [[ "$systemlogset" == "0" ]] && [ -f "/opt/var/log/messages" ] && [ -s "/opt/var/log/messages" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Entware syslog-ng package is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if System Log is located in TMP Directory
[[ "$systemlogset" == "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Checking if System Log is located at /tmp/syslog.log and isn't a blank file"
if [[ "$systemlogset" == "0" ]] && { [ -f "/tmp/syslog.log" ] && [ -s "/tmp/syslog.log" ] ;} >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - System Log is located at /tmp/syslog.log"
  SYSLOG="/tmp/syslog.log" && systemlogset=1
fi

# Check if System Log is located in JFFS Directory
[[ "$systemlogset" == "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Checking if System Log is located at /jffs/syslog.log and isn't a blank file"
if [[ "$systemlogset" == "0" ]] && { [ -f "/jffs/syslog.log" ] && [ -s "/jffs/syslog.log" ] ;} >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - System Log is located at /jffs/syslog.log"
  SYSLOG="/jffs/syslog.log" && systemlogset=1
fi

# Determine if System Log Path was located and load Monitor Mode
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1;then
  echo -e "${RED}***Unable to locate System Log Path***${NOCOLOR}"
  logger -p 2 -t "${0##*/}" "Monitor - ***Unable to locate System Log Path***"
  return
elif [[ "$systemlogset" == "1" ]] >/dev/null 2>&1;then
  if [[ "$mode" == "monitor" ]] >/dev/null 2>&1;then
    tail -1 -F $SYSLOG | awk '/'${0##*/}'/{print}' 2>/dev/null && { systemlogset=0 && return ;} || echo -e "${RED}***Unable to load Monitor Mode***${NOCOLOR}"
  elif [[ "$mode" == "capture" ]] >/dev/null 2>&1;then
    LOGFILE="/tmp/wan-failover-$(date +"%F-%T-%Z").log"
    touch -a $LOGFILE
    tail -1 -F $SYSLOG | awk '/'${0##*/}'/{print}' | tee -a "$LOGFILE"
  fi
fi
}

# Set Variables
setvariables ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: setvariables"
# Set Variables from Configuration
logger -p 6 -t "${0##*/}" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

# Check Configuration File for Missing Settings and Set Default if Missing
logger -p 6 -t "${0##*/}" "Debug - Checking for missing configuration options"
if [ -z "$(sed -n '/\bWAN0TARGET=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [ ! -z "$(nvram get wandog_target)" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0TARGET Default: "$(nvram get wandog_target)""
    echo -e "WAN0TARGET=$(nvram get wandog_target)" >> $CONFIGFILE
  else
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0TARGET Default: 8.8.8.8"
    echo -e "WAN0TARGET=8.8.8.8" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1TARGET=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1TARGET Default: 8.8.4.4"
  echo -e "WAN1TARGET=8.8.4.4" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGCOUNT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PINGCOUNT Default: 3 Seconds"
  echo -e "PINGCOUNT=3" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGTIMEOUT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PINGTIMEOUT Default: 1 Second"
  echo -e "PINGTIMEOUT=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0PACKETSIZE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  PACKETSIZE=${PACKETSIZE:=56}
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0PACKETSIZE Default: "$PACKETSIZE" Bytes"
  echo -e "WAN0PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1PACKETSIZE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  PACKETSIZE=${PACKETSIZE:=56}
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1PACKETSIZE Default: "$PACKETSIZE" Bytes"
  echo -e "WAN1PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWANDISABLEDSLEEPTIMER=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WANDISABLEDSLEEPTIMER Default: 10 Seconds"
  echo -e "WANDISABLEDSLEEPTIMER=10" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_ENABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_ENABLE Default: Enabled"
    echo -e "WAN0_QOS_ENABLE=1" >> $CONFIGFILE
  elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_ENABLE Default: Disabled"
    echo -e "WAN0_QOS_ENABLE=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_ENABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_ENABLE Default: Enabled"
    echo -e "WAN1_QOS_ENABLE=1" >> $CONFIGFILE
  elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_ENABLE Default: Disabled"
    echo -e "WAN1_QOS_ENABLE=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN0_QOS_IBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$(nvram get qos_enable)" == "1" ]] && [[ "$(nvram get qos_ibw)" != "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_IBW Default: "$(nvram get qos_ibw)" Kbps"
    echo -e "WAN0_QOS_IBW=$(nvram get qos_ibw)" >> $CONFIGFILE
  else
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
    echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_IBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_IBW Default: 0 Mbps"
  echo -e "WAN1_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_OBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$(nvram get qos_enable)" == "1" ]] && [[ "$(nvram get qos_obw)" != "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_OBW Default: "$(nvram get qos_obw)" Kbps"
    echo -e "WAN0_QOS_OBW=$(nvram get qos_obw)" >> $CONFIGFILE
  else
    logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
    echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_OBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_OBW Default: 0 Mbps"
  echo -e "WAN1_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN0_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN1_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_ATM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_ATM Default: Disabled"
  echo -e "WAN0_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1_QOS_ATM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_ATM Default: Disabled"
  echo -e "WAN1_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPACKETLOSSLOGGING=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PACKETLOSSLOGGING Default: Enabled"
  echo -e "PACKETLOSSLOGGING=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSENDEMAIL=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting SENDEMAIL Default: Enabled"
  echo -e "SENDEMAIL=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSKIPEMAILSYSTEMUPTIME=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting SKIPEMAILSYSTEMUPTIME Default: 180 Seconds"
  echo -e "SKIPEMAILSYSTEMUPTIME=180" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bEMAILTIMEOUT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "EMAILTIMEOUT=30" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bBOOTDELAYTIMER=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting BOOTDELAYTIMER Default: 0 Seconds"
  echo -e "BOOTDELAYTIMER=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNSPLITTUNNEL=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNSPLITTUNNEL Default: Enabled"
  echo -e "OVPNSPLITTUNNEL=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0ROUTETABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0ROUTETABLE Default: Table 100"
  echo -e "WAN0ROUTETABLE=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1ROUTETABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1ROUTETABLE Default: Table 200"
  echo -e "WAN1ROUTETABLE=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN0TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN1TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0MARK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0MARK Default: 0x80000000"
  echo -e "WAN0MARK=0x80000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1MARK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1MARK Default: 0x90000000"
  echo -e "WAN1MARK=0x90000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0MASK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0MASK Default: 0xf0000000"
  echo -e "WAN0MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1MASK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1MASK Default: 0xf0000000"
  echo -e "WAN1MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bLBRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting LBRULEPRIORITY Default: Priority 150"
  echo -e "LBRULEPRIORITY=150" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bFROMWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting FROMWAN0PRIORITY Default: Priority 200"
  echo -e "FROMWAN0PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bTOWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting TOWAN0PRIORITY Default: Priority 400"
  echo -e "TOWAN0PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bFROMWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting FROMWAN1PRIORITY Default: Priority 200"
  echo -e "FROMWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bTOWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting TOWAN1PRIORITY Default: Priority 400"
  echo -e "TOWAN1PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN0PRIORITY Default: Priority 100"
  echo -e "OVPNWAN0PRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "OVPNWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bRECURSIVEPINGCHECK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Setting RECURSIVEPINGCHECK Default: 1 Iteration"
  echo -e "RECURSIVEPINGCHECK=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bDEVMODE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Creating DEVMODE Default: Disabled"
  echo -e "DEVMODE=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bCHECKNVRAM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Creating CHECKNVRAM Default: Disabled"
  echo -e "CHECKNVRAM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Creating CUSTOMLOGPATH Default: N/A"
  echo -e "CUSTOMLOGPATH=" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSCHEDULECRONJOB=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Creating SCHEDULECRONJOB Default: Enabled"
  echo -e "SCHEDULECRONJOB=1" >> $CONFIGFILE
fi

# Cleanup Config file of deprecated options
DEPRECATEDOPTIONS='
WAN0SUFFIX
WAN1SUFFIX
INTERFACE6IN4
RULEPRIORITY6IN4
PACKETSIZE
'

for DEPRECATEDOPTION in ${DEPRECATEDOPTIONS};do
if [ ! -z "$(sed -n '/\b'${DEPRECATEDOPTION}'=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Removing deprecated option: "${DEPRECATEDOPTION}" from "$CONFIGFILE""
  sed -i '/\b'${DEPRECATEDOPTION}'=\b/d' $CONFIGFILE
fi
done

logger -p 6 -t "${0##*/}" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
'

  # Create Array for OVPN Remote Addresses
  REMOTEADDRESSES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [ -f "${OVPNCONFIGFILE}" ] >/dev/null 2>&1;then
      REMOTEADDRESS="$(awk -F " " '/remote/ {print $2}' "$OVPNCONFIGFILE")"
      logger -p 6 -t "${0##*/}" "Debug - Added $REMOTEADDRESS to OVPN Remote Addresses"
      REMOTEADDRESSES="${REMOTEADDRESSES} ${REMOTEADDRESS}"
    fi
  done
fi

# Debug Logging
debuglog || return

return
}

# WAN Status
wanstatus ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wanstatus"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

# Boot Delay Timer
logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
logger -p 6 -t "${0##*/}" "Debug - Boot Delay Timer: "$BOOTDELAYTIMER" Seconds"
if [ ! -z "$BOOTDELAYTIMER" ] >/dev/null 2>&1;then
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null 2>&1;then
    logger -p 4 -st "${0##*/}" "Boot Delay - Waiting for System Uptime to reach $BOOTDELAYTIMER seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null 2>&1;do
      sleep 1
    done
    logger -p 5 -st "${0##*/}" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi

# Check Current Status of Dual WAN Mode
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null 2>&1;then
  logger -p 2 -st "${0##*/}" "WAN Status - Dual WAN: Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null 2>&1;then
  logger -p 2 -st "${0##*/}" "WAN Status - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
else
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    getwanparameters || return

    # Check if WAN Interfaces are Disabled
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null 2>&1;then
      logger -p 1 -st "${0##*/}" "WAN Status - ${WANPREFIX} disabled"
      STATUS=DISABLED
      logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
      setwanstatus && continue
    # Check if WAN is Enabled
    elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null 2>&1;then
      logger -p 5 -t "${0##*/}" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN Connection
      logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" State"
      if [[ "$(nvram get "${WANPREFIX}"_auxstate_t)" == "1" ]] || [ -z "$(nvram get "${WANPREFIX}"_gw_ifname)" ] || { [[ "$WANUSB" == "usb" ]] && { [[ "$(nvram get "${WANPREFIX}"_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get "${WANPREFIX}"_ifname)" ] ;} ;} >/dev/null 2>&1;then
        [[ "$WANUSB" != "usb" ]] && logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
        [[ "$WANUSB" == "usb" ]] && logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": USB Unplugged" && RESTARTSERVICESMODE=2 && restartservices
        STATUS=UNPLUGGED
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
        setwanstatus && continue
      elif { [[ "$(nvram get "${WANPREFIX}"_auxstate_t)" != "1" ]] || { [[ "$WANUSB" == "usb" ]] && { [[ "$(nvram get "${WANPREFIX}"_is_usb_modem_ready)" == "1" ]] && [ ! -z "$(nvram get "${WANPREFIX}"_ifname)" ] ;} ;} ;} && { [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] && [[ "$(nvram get "${WANPREFIX}"_state_t)" != "6" ]] ;} >/dev/null 2>&1;then
        logger -p 1 -st "${0##*/}" "WAN Status - Restarting "${WANPREFIX}""
        WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
        service "restart_wan_if "$WANSUFFIX"" &
        # Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
        RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
        while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] >/dev/null 2>&1;do
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] >/dev/null 2>&1;then
            continue
          elif  [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] || [[ "$(nvram get "${WANPREFIX}"_auxstate_t)" == "1" ]] >/dev/null 2>&1;then
            break
          else
            sleep 1
          fi
        done
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Post-Restart State: "$(nvram get ${WANPREFIX}_state_t)""
        if { [[ "$(nvram get "${WANPREFIX}"_auxstate_t)" != "1" ]] || { [[ "$WANUSB" == "usb" ]] && { [[ "$(nvram get "${WANPREFIX}"_is_usb_modem_ready)" == "1" ]] && [ ! -z "$(nvram get "${WANPREFIX}"_ifname)" ] ;} ;} ;} && { [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] && [[ "$(nvram get "${WANPREFIX}"_state_t)" != "6" ]] ;} >/dev/null 2>&1;then
          logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Disconnected"
          STATUS=DISCONNECTED
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
          setwanstatus && continue
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null 2>&1;then
          logger -p 4 -st "${0##*/}" "WAN Status - Successfully Restarted "${WANPREFIX}""
          [[ "$WANUSB" == "usb" ]] && [[ "$(nvram get "${WANPREFIX}"_is_usb_modem_ready)" == "1" ]] && RESTARTSERVICESMODE=2 && restartservices
          sleep 5
        else
          wanstatus
        fi
      fi

      # Check if WAN Gateway IP or IP Address are 0.0.0.0 or null
      logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for null IP or Gateway"
      if { { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get ${WANPREFIX}_ipaddr)" ] ;} || { [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get ${WANPREFIX}_gateway)" ] ;} ;} >/dev/null 2>&1;then
        [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] && logger -p 2 -st "${0##*/}" "WAN Status - ***Error*** ${WANPREFIX} IP Address: "$(nvram get ${WANPREFIX}_ipaddr)""
        [ -z "$(nvram get ${WANPREFIX}_ipaddr)" ] && logger -p 2 -st "${0##*/}" "WAN Status - ***Error*** ${WANPREFIX} IP Address: Null"
        [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] && logger -p 2 -st "${0##*/}" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: "$(nvram get ${WANPREFIX}_gateway)""
        [ -z "$(nvram get ${WANPREFIX}_gateway)" ] && logger -p 2 -st "${0##*/}" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: Null"
        STATUS=DISCONNECTED
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
        setwanstatus && continue
      fi

      # Check WAN Routing Table for Default Routes
      logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
      if [ -z "$(ip route list default table "$TABLE" | grep -w "$(nvram get ${WANPREFIX}_gw_ifname)")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "WAN Status - Adding default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        ip route add default via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) table "$TABLE" \
        && logger -p 4 -t "${0##*/}" "WAN Status - Added default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"" \
        || { logger -p 2 -t "${0##*/}" "WAN Status - ***Error*** Unable to add default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"" && sleep 1 && wanstatus ;}
      fi

      # Check WAN Packet Loss
      logger -p 6 -t "${0##*/}" "Debug - Recursive Ping Check: "$RECURSIVEPINGCHECK""
      i=1
      while [ "$i" -le "$RECURSIVEPINGCHECK" ] >/dev/null 2>&1;do
        # Determine IP Rule or Route for successful ping
        PINGPATH=${PINGPATH:=0}
        # Check WAN Target IP Rule specifying Outbound Interface
        logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for IP Rule to "$TARGET""
        if [[ "$PINGPATH" == "0" ]] || [[ "$PINGPATH" == "1" ]] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from all iif lo to $TARGET oif "$(nvram get ${WANPREFIX}_gw_ifname)" lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "WAN Status - Adding IP Rule for "$TARGET" to monitor "${WANPREFIX}""
            ip rule add from all iif lo to $TARGET oif $(nvram get ${WANPREFIX}_gw_ifname) table ${TABLE} priority "$PRIORITY" \
            && logger -p 4 -t "${0##*/}" "WAN Status - Added IP Rule for "$TARGET" to monitor "${WANPREFIX}"" \
            || { logger -p 2 -t "${0##*/}" "WAN Status - ***Error*** Unable to add IP Rule for "$TARGET" to monitor "${WANPREFIX}"" && sleep 1 && wanstatus ;}
          fi
          logger -p 6 -t "${0##*/}" "Debug - "Checking ${WANPREFIX}" for packet loss via $TARGET - Attempt: "$i""
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(cat /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          [[ "$PINGPATH" != "0" ]] && [[ "$PACKETLOSS" != "0%" ]] && WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')" && service "restart_wan_if "$WANSUFFIX""
          [[ "$PACKETLOSS" == "0%" ]] && PINGPATH=1
          [[ "$PINGPATH" == "0" ]] && [[ "$PACKETLOSS" != "0%" ]] && ip rule del from all iif lo to $TARGET oif $(nvram get ${WANPREFIX}_gw_ifname) table ${TABLE} priority "$PRIORITY"
        fi

        # Check WAN Target IP Rule without specifying Outbound Interface
        if [[ "$PINGPATH" == "0" ]] || [[ "$PINGPATH" == "2" ]] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from all iif lo to $TARGET lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "WAN Status - Adding IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface"
            ip rule add from all iif lo to $TARGET table ${TABLE} priority "$PRIORITY" \
            && logger -p 4 -t "${0##*/}" "WAN Status - Added IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface" \
            || { logger -p 2 -t "${0##*/}" "WAN Status - ***Error*** Unable to add IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(cat /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          [[ "$PACKETLOSS" == "0%" ]] && PINGPATH=2 && logger -p 3 -t "${0##*/}" "WAN Status - ***Warning*** Compatibility issues with "$TARGET" may occur without specifying Outbound Interface"
          [[ "$PINGPATH" == "0" ]] && [[ "$PACKETLOSS" != "0%" ]] && ip rule del from all iif lo to $TARGET table ${TABLE} priority "$PRIORITY"
        fi

        # Check WAN Route for Target IP
        logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
        if [[ "$PINGPATH" == "0" ]] || [[ "$PINGPATH" == "3" ]] >/dev/null 2>&1;then
          if [ -z "$(ip route list "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "WAN Status - Adding route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
            ip route add $TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) \
            && logger -p 4 -t "${0##*/}" "WAN Status - Added route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"" \
            || { logger -p 2 -t "${0##*/}" "WAN Status - ***Error*** Unable to add route for "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)"" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(cat /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          [[ "$PACKETLOSS" == "0%" ]] && PINGPATH=3 && logger -p 3 -t "${0##*/}" "WAN Status - ***Warning*** Compatibility issues with "$TARGET" may occur with adding route via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
          [[ "$PINGPATH" == "0" ]] && [[ "$PACKETLOSS" != "0%" ]] && ip route del $TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname)
        fi
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Ping Path: "$PINGPATH""
        if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1;then
          WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
          service "restart_wan_if "$WANSUFFIX"" &
        fi

        # Determine WAN Status based on Packet Loss
        if { [[ "$PACKETLOSS" == "0%" ]] || [[ "$PACKETLOSS" != "100%" ]] ;} && [ ! -z "$PACKETLOSS" ] >/dev/null 2>&1;then
          logger -p 5 -t "${0##*/}" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
          STATUS="CONNECTED"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
          [[ "$(nvram get ${WANPREFIX}_state_t)" != "2" ]] && nvram set ${WANPREFIX}_state_t=2
          setwanstatus && break 1
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
          logger -p 2 -st "${0##*/}" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss ***Verify $TARGET is a valid server for ICMP Echo Requests***"
          STATUS="DISCONNECTED"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        else
          logger -p 2 -st "${0##*/}" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
          STATUS="DISCONNECTED"
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        fi
      done
      PINGPATH=""
      i=""
    fi
  done
fi

# Debug Logging
debuglog || return

# Update DNS
switchdns || return

# Check IP Rules and IPTables Rules
checkiprules || return

# Set Status for Email Notification On if Unset
email=${email:=1}

# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
logger -p 6 -t "${0##*/}" "Debug - WAN0STATUS: "$WAN0STATUS""
logger -p 6 -t "${0##*/}" "Debug - WAN1STATUS: "$WAN1STATUS""

# Checking if WAN Disabled returned to WAN Status and resetting loop iterations if WAN Status has changed
wandisabledloop=${wandisabledloop:=0}
[[ "$wandisabledloop" != "0" ]] && logger -p 6 -t "${0##*/}" "Debug - Returning to WAN Disabled" && wandisabled
[[ "$wandisabledloop" == "0" ]] && wandisabledloop="" && wan0disabled="" && wan1disabled=""

# Determine which function to go to based on Failover Mode and WAN Status
if [[ "${mode}" == "initiate" ]] >/dev/null 2>&1;then
  logger -p 4 -st "${0##*/}" "WAN Status - Initiate Completed"
  return
elif [[ "$WAN0STATUS" != "CONNECTED" ]] && [[ "$WAN1STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
  wandisabled
elif [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$WAN0STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$(nvram get wan0_primary)" == "1" ]] && SWITCHPRIMARY=0 && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$(nvram get wan0_primary)" != "1" ]] && { logger -p 6 -t "${0##*/}" "Debug - WAN0 is not Primary WAN" && failover ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] && sendemail && email=0
  # Determine which function to use based on Secondary WAN
  [[ "$WAN1STATUS" == "CONNECTED" ]] && wan0failovermonitor
  [[ "$WAN1STATUS" == "UNPLUGGED" ]] && wandisabled
  [[ "$WAN1STATUS" == "DISCONNECTED" ]] && wandisabled
  [[ "$WAN1STATUS" == "DISABLED" ]] && wandisabled
elif [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$(nvram get wan1_primary)" == "1" ]] && SWITCHPRIMARY=0 && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$(nvram get wan1_primary)" != "1" ]] && { logger -p 6 -t "${0##*/}" "Debug - WAN1 is not Primary WAN" && failover && email=0 ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] && sendemail && email=0
  # Determine which function to use based on Secondary WAN
  [[ "$WAN0STATUS" == "UNPLUGGED" ]] && wandisabled
  [[ "$WAN0STATUS" == "DISCONNECTED" ]] && { [ ! -z "$WAN0PACKETLOSS" ] && [[ "$WAN0PACKETLOSS" == "100%" ]] && wan0failbackmonitor || wandisabled ;}
  [[ "$WAN0STATUS" == "DISABLED" ]] && wandisabled
elif [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
  lbmonitor
else
  wanstatus
fi
}

# Check IP Rules and IPTables Rules
checkiprules ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: checkiprules"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  getwanparameters || return

  # Check Rules if Status is Connected
  if [[ "$STATUS" == "CONNECTED" ]] || { [[ "$(nvram get ${WANPREFIX}_enable)" == "1" ]] && { [[ "$(nvram get ${WANPREFIX}_state_t)" == "2" ]] || [[ "$(nvram get ${WANPREFIX}_auxstate_t)" != "1" ]] ;} ;} >/dev/null 2>&1;then
    # Create WAN NAT Rules
    # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
    if [[ "$(nvram get misc_http_x)" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "${0##*/}" "Debug - HTTP Web Access: "$(nvram get misc_http_x)""
      # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
      if [ -z "$(iptables -t nat -L PREROUTING -v -n | awk '{ if( /VSERVER/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}' )" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - "${WANPREFIX}" creating VSERVER Rule for "$(nvram get ${WANPREFIX}_ipaddr)""
        iptables -t nat -A PREROUTING -d $(nvram get ${WANPREFIX}_ipaddr) -j VSERVER \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - "${WANPREFIX}" created VSERVER Rule for "$(nvram get ${WANPREFIX}_ipaddr)"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** "${WANPREFIX}" unable to create VSERVER Rule for "$(nvram get ${WANPREFIX}_ipaddr)""
      fi
    fi
    # Create UPNP Rules if Enabled
    if [[ "$(nvram get ${WANPREFIX}_upnp_enable)" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" UPNP Enabled: "$(nvram get ${WANPREFIX}_upnp_enable)""
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /PUPNP/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ ) print}' )" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - "${WANPREFIX}" creating UPNP Rule for "$(nvram get ${WANPREFIX}_gw_ifname)""
        iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) -j PUPNP \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - "${WANPREFIX}" created UPNP Rule for "$(nvram get ${WANPREFIX}_gw_ifname)"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - *** Error*** "${WANPREFIX}" unable to create UPNP Rule for "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
    fi
    # Create MASQUERADE Rules if NAT is Enabled
    if [[ "$(nvram get ${WANPREFIX}_nat_x)" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" NAT Enabled: "$(nvram get ${WANPREFIX}_nat_x)""
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /MASQUERADE/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding iptables MASQUERADE rule for excluding "$(nvram get ${WANPREFIX}_ipaddr)" via "$(nvram get ${WANPREFIX}_gw_ifname)""
        iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) ! -s $(nvram get ${WANPREFIX}_ipaddr) -j MASQUERADE \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added iptables MASQUERADE rule for excluding "$(nvram get ${WANPREFIX}_ipaddr)" via "$(nvram get ${WANPREFIX}_gw_ifname)"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add iptables MASQUERADE rule for excluding "$(nvram get ${WANPREFIX}_ipaddr)" via "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
    fi
  fi

  # Check Rules for Load Balance Mode
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Checking IPTables Mangle Rules"
    # Check IPTables Mangle Balance Rules for PREROUTING Table
    if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$(nvram get lan_ifname)'/ && /state/ && /NEW/ ) print}')" ] >/dev/null 2>&1;then
      logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$(nvram get lan_ifname)""
      iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m state --state NEW -j balance \
      && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$(nvram get lan_ifname)"" \
      || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$(nvram get lan_ifname)""
    fi

    # Check Rules if Status is Connected
    if [[ "$STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
      # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get lan_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables - PREROUTING MANGLE match rule for "$(nvram get lan_ifname)" marked with "$MARK""
        iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables - PREROUTING MANGLE match rule for "$(nvram get lan_ifname)" marked with "$MARK"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IPTables - PREROUTING MANGLE match rule for "$(nvram get lan_ifname)" marked with "$MARK""
      fi
      # Check IPTables Mangle Match Rule for WAN for OUTPUT Table
      if [ -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$MARK""
        iptables -t mangle -A OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$MARK"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$MARK""
      fi
      if [ ! -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$DELETEMARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 6 -t "${0##*/}" "Check IP Rules - Deleting IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$DELETEMARK""
        iptables -t mangle -D OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 6 -t "${0##*/}" "Check IP Rules - Deleted IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$DELETEMARK"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to delete IPTables - OUTPUT MANGLE match rule for "$(nvram get ${WANPREFIX}_gw_ifname)" marked with "$DELETEMARK""
      fi
      # Check IPTables Mangle Set XMark Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /state/ && /NEW/ && /CONNMARK/ && /xset/ && /'$MARK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables - PREROUTING MANGLE set xmark rule for "$(nvram get ${WANPREFIX}_gw_ifname)""
        iptables -t mangle -A PREROUTING -i $(nvram get ${WANPREFIX}_gw_ifname) -m state --state NEW -j CONNMARK --set-xmark "$MARK"/"$MASK" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables - PREROUTING MANGLE set xmark rule for "$(nvram get ${WANPREFIX}_gw_ifname)"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to delete IPTables - PREROUTING MANGLE set xmark rule for "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
      # Create WAN IP Address Rule
      if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get ${WANPREFIX}_ipaddr)" ] ;} && [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for "$(nvram get ${WANPREFIX}_ipaddr)" lookup "${TABLE}""
        ip rule add from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for "$(nvram get ${WANPREFIX}_ipaddr)" lookup "${TABLE}"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for "$(nvram get ${WANPREFIX}_ipaddr)" lookup "${TABLE}""
      fi
      # Create WAN Gateway IP Rule
      if { [[ "$(nvram get ${WANPREFIX}_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get ${WANPREFIX}_gateway)" ] ;} && [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to "$(nvram get ${WANPREFIX}_gateway)" lookup "${TABLE}""
        ip rule add from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule from all to "$(nvram get ${WANPREFIX}_gateway)" lookup "${TABLE}"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$(nvram get ${WANPREFIX}_gateway)" lookup "${TABLE}""
      fi
      # Create WAN DNS IP Rules
      if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null 2>&1;then
        if [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$(nvram get ${WANPREFIX}_dns1_x)" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}""
            ip rule add from $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}""
          fi
          if [ -z "$(ip rule list from all to "$(nvram get ${WANPREFIX}_dns1_x)" lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}""
            ip rule add from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule from all to "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$(nvram get ${WANPREFIX}_dns1_x)" lookup "${TABLE}""
          fi
        fi
        if [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$(nvram get ${WANPREFIX}_dns2_x)" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}""
            ip rule add from $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}""
          fi
          if [ -z "$(ip rule list from all to "$(nvram get ${WANPREFIX}_dns2_x)" lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}""
            ip rule add from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule from all to "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$(nvram get ${WANPREFIX}_dns2_x)" lookup "${TABLE}""
          fi
        fi
      elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null 2>&1;then
        if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" lookup "${TABLE}""
            ip rule add from $(nvram get ${WANPREFIX}_dns | awk '{print $1}') lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" lookup "${TABLE}""
          fi
        fi
        if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" lookup "${TABLE}""
            ip rule add from $(nvram get ${WANPREFIX}_dns | awk '{print $2}') lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" lookup "${TABLE}"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" lookup "${TABLE}""
          fi
        fi
      fi

      # Check Guest Network Rules for Load Balance Mode
      logger -p 6 -t "${0##*/}" "Debug - Checking Guest Networks IPTables Mangle Rules"
      i=0
      while [ "$i" -le "10" ] >/dev/null 2>&1;do
        i=$(($i+1))
        if [ ! -z "$(nvram get lan${i}_ifname)" ] >/dev/null 2>&1;then
          if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$(nvram get lan${i}_ifname)'/ && /state/ && /NEW/ ) print}')" ] >/dev/null 2>&1;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$(nvram get lan${i}_ifname)""
            iptables -t mangle -A PREROUTING -i $(nvram get lan${i}_ifname) -m state --state NEW -j balance \
            && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$(nvram get lan${i}_ifname)"" \
            || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$(nvram get lan${i}_ifname)""
          fi
        fi
  
        # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
        if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get lan${i}_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
          logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE match rule for "$(nvram get lan${i}_ifname)" marked with "$MARK""
          iptables -t mangle -A PREROUTING -i $(nvram get lan${i}_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
          && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IPTables MANGLE match rule for "$(nvram get lan${i}_ifname)" marked with "$MARK"" \
          || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE match rule for "$(nvram get lan${i}_ifname)" marked with "$MARK""
        fi
      done
      i=0

      # Create fwmark IP Rules
      logger -p 6 -t "${0##*/}" "Debug - Checking fwmark IP Rules"
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule add from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
          || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Removing Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule del blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "${0##*/}" "Check IP Rules - Removed Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
          || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to remove Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules for WAN Interface.
      logger -p 6 -t "${0##*/}" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
        # Create IP Rules for OVPN Remote Addresses
          for REMOTEADDRESS in ${REMOTEADDRESSES};do
            REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
            logger -p 6 -t "${0##*/}" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
            if [ ! -z "$REMOTEIP" ] >/dev/null 2>&1;then
              logger -p 6 -t "${0##*/}" "Debug - Remote IP Address: "$REMOTEIP""
              if [ -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null 2>&1;then
                logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
                ip rule add from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY" \
                && logger -p 4 -t "${0##*/}" "Check IP Rules - Added IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY"" \
                || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
              fi
            else
              logger -p 6 -t "${0##*/}" "Debug - Unable to query "$REMOTEADDRESS""
            fi
          done
      fi

    # Check Rules if Status is Disconnected
    elif [[ "$STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
      # Create fwmark IP Rules
      logger -p 6 -t "${0##*/}" "Debug - Checking fwmark IP Rules"
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Removing IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule del from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Removed IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to remove IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null 2>&1;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule add blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "${0##*/}" "Check IP Rules - Added Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
        || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to add Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi
      
      # If OVPN Split Tunneling is Disabled in Configuration, delete rules for down WAN Interface.
      logger -p 6 -t "${0##*/}" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          logger -p 6 -t "${0##*/}" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
          REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
          if [ ! -z "$REMOTEIP" ] >/dev/null 2>&1;then
            logger -p 6 -t "${0##*/}" "Debug - Remote IP Address: "$REMOTEIP""
            if [ ! -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null 2>&1;then
              logger -p 5 -t "${0##*/}" "Check IP Rules - Removing IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
              ip rule del from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY" \
              && logger -p 4 -t "${0##*/}" "Check IP Rules - Removed IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY"" \
              || logger -p 2 -t "${0##*/}" "Check IP Rules - ***Error*** Unable to remove IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
            fi
          else
            logger -p 6 -t "${0##*/}" "Debug - Unable to query "$REMOTEADDRESS""
          fi
        done
      fi
    fi
  fi
done
return
}

# Get WAN Parameters
getwanparameters ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: getwanparameters"

# Set WAN Interface Parameters
logger -p 6 -t "${0##*/}" "Debug - Setting parameters for "${WANPREFIX}""
if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
  TARGET="$WAN0TARGET"
  TABLE="$WAN0ROUTETABLE"
  PRIORITY="$WAN0TARGETRULEPRIORITY"
  WANUSB="$(nvram get wans_dualwan | awk '{print $1}')"
  WAN0PINGPATH=${WAN0PINGPATH:=0}
  PINGPATH="$WAN0PINGPATH"
  MARK="$WAN0MARK"
  DELETEMARK="$WAN1MARK"
  MASK="$WAN0MASK"
  FROMWANPRIORITY="$FROMWAN0PRIORITY"
  TOWANPRIORITY="$TOWAN0PRIORITY"
  OVPNWANPRIORITY="$OVPNWAN0PRIORITY"
  WAN_QOS_ENABLE="$WAN0_QOS_ENABLE"
  WAN_QOS_OBW="$WAN0_QOS_OBW"
  WAN_QOS_IBW="$WAN0_QOS_IBW"
  WAN_QOS_OVERHEAD="$WAN0_QOS_OVERHEAD"
  WAN_QOS_ATM="$WAN0_QOS_ATM"
  if [[ "$(nvram get wans_mode)" != "lb" ]] >/dev/null 2>&1;then
    [[ "$(nvram get wan0_primary)" == "1" ]] && WAN0STATUS=${WAN0STATUS:=CONNECTED}
    [[ "$(nvram get wan0_primary)" == "0" ]] && WAN0STATUS=${WAN0STATUS:=DISCONNECTED}
    [[ "$(nvram get wan0_primary)" == "0" ]] && [[ "$(nvram get wan0_auxstate_t)" == "1" ]] && WAN0STATUS=${WAN0STATUS:=UNPLUGGED}
  elif [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    [[ "$(nvram get wan0_state_t)" == "2" ]] && WAN0STATUS=${WAN0STATUS:=CONNECTED}
    [[ "$(nvram get wan0_state_t)" != "2" ]] && WAN0STATUS=${WAN0STATUS:=DISCONNECTED}
    [[ "$(nvram get wan0_auxstate_t)" == "1" ]] && WAN0STATUS=${WAN0STATUS:=UNPLUGGED}
  fi
  STATUS=${STATUS:="$WAN0STATUS"}
elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
  TARGET="$WAN1TARGET"
  TABLE="$WAN1ROUTETABLE"
  PRIORITY="$WAN1TARGETRULEPRIORITY"
  WANUSB="$(nvram get wans_dualwan | awk '{print $2}')"
  WAN1PINGPATH=${WAN1PINGPATH:=0}
  PINGPATH="$WAN1PINGPATH"
  TABLE="$WAN1ROUTETABLE"
  MARK="$WAN1MARK"
  DELETEMARK="$WAN0MARK"
  MASK="$WAN1MASK"
  FROMWANPRIORITY="$FROMWAN1PRIORITY"
  TOWANPRIORITY="$TOWAN1PRIORITY"
  OVPNWANPRIORITY="$OVPNWAN1PRIORITY"
  WAN_QOS_ENABLE="$WAN1_QOS_ENABLE"
  WAN_QOS_OBW="$WAN1_QOS_OBW"
  WAN_QOS_IBW="$WAN1_QOS_IBW"
  WAN_QOS_OVERHEAD="$WAN1_QOS_OVERHEAD"
  WAN_QOS_ATM="$WAN1_QOS_ATM"
  if [[ "$(nvram get wans_mode)" != "lb" ]] >/dev/null 2>&1;then
    [[ "$(nvram get wan1_primary)" == "1" ]] && WAN1STATUS=${WAN1STATUS:=CONNECTED}
    [[ "$(nvram get wan1_primary)" == "0" ]] && WAN1STATUS=${WAN1STATUS:=DISCONNECTED}
    [[ "$(nvram get wan1_primary)" == "0" ]] && [[ "$(nvram get wan1_auxstate_t)" == "1" ]] && WAN1STATUS=${WAN1STATUS:=UNPLUGGED}
  elif [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    [[ "$(nvram get wan1_state_t)" == "2" ]] && WAN1STATUS=${WAN1STATUS:=CONNECTED}
    [[ "$(nvram get wan1_state_t)" != "2" ]] && WAN1STATUS=${WAN1STATUS:=DISCONNECTED}
    [[ "$(nvram get wan1_auxstate_t)" == "1" ]] && WAN1STATUS=${WAN1STATUS:=UNPLUGGED}
  fi
  STATUS=${STATUS:="$WAN1STATUS"}
fi

return
}

# Set WAN Status
setwanstatus ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: setwanstatus"

# Set WANS Status Mode
WANSTATUSMODE=${WANSTATUSMODE:=1}
logger -p 6 -t "${0##*/}" "Debug - WAN Status Mode: "$WANSTATUSMODE""

if [[ "$WANSTATUSMODE" == "1" ]] >/dev/null 2>&1;then
  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
    WAN0STATUS="$STATUS"
    WAN0PINGPATH="$PINGPATH"
    logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
    WAN1STATUS="$STATUS"
    WAN1PINGPATH="$PINGPATH"
    logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
  fi
STATUS=""
fi

if [[ "$WANSTATUSMODE" == "2" ]] >/dev/null 2>&1;then
  [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && { [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$WAN0PACKETLOSS" == "100%" ]] ;} && WAN0STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" != "0" ]] && WAN0STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan0_enable)" == "0" ]] && WAN0STATUS=DISABLED && email=1
  [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && { [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$WAN1PACKETLOSS" == "100%" ]] ;} && WAN1STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" != "0" ]] && WAN1STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan1_enable)" == "0" ]] && WAN1STATUS=DISABLED && email=1
fi

WANSTATUSMODE=""
return
}

# Ping WAN0Target
pingwan0target ()
{
ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}' > /tmp/wan0packetloss.tmp
return
}

# Ping WAN1Target
pingwan1target ()
{
ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}' > /tmp/wan1packetloss.tmp
return
}

# Ping Targets
pingtargets ()
{
pingfailure0=${pingfailure0:=0}
pingfailure1=${pingfailure1:=0}
i=1
while [ "$i" -le "$RECURSIVEPINGCHECK" ] >/dev/null 2>&1;do
  pingwan0target &
  PINGWAN0PID=$!
  pingwan1target &
  PINGWAN1PID=$!
  wait $PINGWAN0PID $PINGWAN1PID
  { [ -z "$(nvram get wan0_ifname)" ] || [ -z "$(nvram get wan0_gw_ifname)" ] ;} && WAN0PACKETLOSS="100%" || WAN0PACKETLOSS="$(cat /tmp/wan0packetloss.tmp)"
  { [ -z "$(nvram get wan1_ifname)" ] || [ -z "$(nvram get wan1_gw_ifname)" ] ;} && WAN1PACKETLOSS="100%" || WAN1PACKETLOSS="$(cat /tmp/wan1packetloss.tmp)"
  if [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN0PACKETLOSS" "${WHITE}"WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
    fi
    [[ "$pingfailure0" != "0" ]] && logger -p 1 -st "${0##*/}" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" != "0" ]] && logger -p 1 -st "${0##*/}" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    break 1
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    [[ "$pingfailure0" == "0" ]] && logger -p 1 -st "${0##*/}" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=1
    [[ "$pingfailure1" != "0" ]] && logger -p 1 -st "${0##*/}" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${RED}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
      if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] >/dev/null 2>&1;then
        printf '\a'
      fi
    fi
    i=$(($i+1))
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
    [[ "$pingfailure0" != "0" ]] && logger -p 1 -st "${0##*/}" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" == "0" ]] && logger -p 1 -st "${0##*/}" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${RED}""$WAN1PACKETLOSS""${NOCOLOR}""
      if [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
        printf '\a'
      fi
    fi
    i=$(($i+1))
    continue
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
    [[ "$pingfailure0" == "0" ]] && logger -p 1 -st "${0##*/}" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=1
    [[ "$pingfailure1" == "0" ]] && logger -p 1 -st "${0##*/}" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${RED}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${RED}""$WAN1PACKETLOSS""${NOCOLOR}""
      if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
        printf '\a'
      fi
    fi
    i=$(($i+1))
    continue
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] && [ ! -z "$WAN0PACKETLOSS" ] ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] && [ ! -z "$WAN1PACKETLOSS" ] ;} >/dev/null 2>&1;then
    [[ "$PACKETLOSSLOGGING" == "1" ]] && logger -p 3 -st "${0##*/}" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] && logger -p 3 -st "${0##*/}" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${YELLOW}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${YELLOW}""$WAN1PACKETLOSS""${NOCOLOR}""
    fi
    i=$(($i+1))
    continue
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] && [ ! -z "$WAN0PACKETLOSS" ] ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    [[ "$PACKETLOSSLOGGING" == "1" ]] && logger -p 3 -st "${0##*/}" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${YELLOW}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
    fi
    i=$(($i+1))
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && { [[ "$WAN1PACKETLOSS" != "0%" ]] && [ ! -z "$WAN1PACKETLOSS" ] ;} >/dev/null 2>&1;then
    [[ "$PACKETLOSSLOGGING" == "1" ]] && logger -p 3 -st "${0##*/}" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}"$(date "+%D @ %T") - WAN0 Target: "${BLUE}""$WAN0TARGET" "${WHITE}"Packet Loss: "${GREEN}""$WAN0PACKETLOSS""${WHITE}" WAN1 Target: "${BLUE}""$WAN1TARGET" "${WHITE}"Packet Loss: "${YELLOW}""$WAN1PACKETLOSS""${NOCOLOR}""
    fi
    i=$(($i+1))
    continue
  fi
done
i=""
return
}

# Failover
failover ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: failover"

# Disable Email Notification if Mode is Switch WAN
[[ "${mode}" == "switchwan" ]] && email=0

# Set Status for Email Notification On if Unset
email=${email:=1}

[[ "$(nvram get wans_mode)" != "lb" ]] && switchwan || return
switchdns || return
restartservices || return
checkiprules || return
[[ "$email" == "1" ]] && { sendemail && email=0 ;} || return
return
}

# Load Balance Monitor
lbmonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: lbmonitor"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

[[ "$WAN0STATUS" == "CONNECTED" ]] && logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
[[ "$WAN0STATUS" != "CONNECTED" ]] && logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
[[ "$WAN1STATUS" == "CONNECTED" ]] && logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
[[ "$WAN1STATUS" != "CONNECTED" ]] && logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
while { [[ "$(nvram get wans_mode)" == "lb" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} >/dev/null 2>&1;do
  pingtargets || wanstatus
  if { { [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan0_gateway)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    break
  elif { { [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan1_gateway)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan1_gw_ifname)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    break
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
      [[ "$(nvram get wan0_state_t)" != "2" ]] && nvram set wan0_state_t=2
      [[ "$(nvram get wan1_state_t)" != "2" ]] && nvram set wan1_state_t=2
      continue
    else
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')"
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}') \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}') \
      && { logger -p 4 -st "${0##*/}" "Load Balance Monitor - Added nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')" \
      && logger -p 4 -st "${0##*/}" "Load Balance Monitor - Added nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')" ;} \
      || { logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to add nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')" \
      && logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to add nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')" ;}

      # Set WAN Status and Failover
      WAN0STATUS=CONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
      continue
    else
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 6 -t "${0##*/}" "Debug - Adding nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}') \
      && logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removed nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')" \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to remove nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')"

      # Set WAN Status and Failover
      WAN0STATUS=DISCONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      if [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] ;} >/dev/null 2>&1;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
      continue
    else
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 6 -t "${0##*/}" "Debug - Adding nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}') \
      && logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removed nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')" \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to remove nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"

      # Set WAN Status and Failover
      WAN0STATUS=CONNECTED
      WAN1STATUS=DISCONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      if [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
        logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        continue
      fi
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] ;} >/dev/null 2>&1;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null 2>&1;then
      continue
    else
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $1}')"
      logger -p 5 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(nvram get wans_lb_ratio | awk -F ":" '{print $2}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "${0##*/}" "Load Balance Monitor - ***Error*** Unable to delete default route"

      # Set WAN Status and Check Rules
      checkiprules || return
      if [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 1 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 1 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1;then
    continue
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***Load Balance Monitor Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# WAN0 Failover Monitor
wan0failovermonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wan0failovermonitor"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

logger -p 4 -st "${0##*/}" "WAN0 Failover Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failure"
logger -p 4 -st "${0##*/}" "WAN0 Failover Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
while [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null 2>&1;do
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan0_gateway)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] && { { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$(nvram get wan1_primary)" == "1" ]] && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan0_enable)" == "1" ]] && { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} ;} >/dev/null 2>&1;then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} >/dev/null 2>&1;then
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan1_gateway)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan1_gw_ifname)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] && { { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$(nvram get wan1_primary)" == "1" ]] && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan0_enable)" == "1" ]] && { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} ;} >/dev/null 2>&1;then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} >/dev/null 2>&1;then
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    [[ "$(nvram get wan0_state_t)" != "2" ]] && nvram set wan0_state_t=2
    [[ "$(nvram get wan1_state_t)" != "2" ]] && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] && email=0
    continue
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $1}')" == "usb" ]] && { [[ "$(nvram get wan0_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan0_ifname)" ] || [[ "$(nvram get link_wan)" == "0" ]] ;} ;} ;} \
  && { [[ "$(nvram get wan1_enable)" == "1" ]] && { [[ "$WAN1PACKETLOSS" == "0%" ]] || [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} ;} >/dev/null 2>&1;then
    WANSTATUSMODE=2 && setwanstatus
    WAN1STATUS=CONNECTED
    logger -p 6 -t "${0##*/}" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "${0##*/}" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "0%" ]] || [[ "$(nvram get wan0_state_t)" == "2" ]] ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "usb" ]] && { [[ "$(nvram get wan1_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan1_ifname)" ] || [[ "$(nvram get link_wan1)" == "0" ]] ;} ;} ;} >/dev/null 2>&1;then
    [[ "$email" == "0" ]] && email=1
    break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $1}')" == "usb" ]] && { [[ "$(nvram get wan0_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan0_ifname)" ] || [[ "$(nvram get link_wan)" == "0" ]] ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "usb" ]] && { [[ "$(nvram get wan1_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan1_ifname)" ] || [[ "$(nvram get link_wan1)" == "0" ]] ;} ;} ;} >/dev/null 2>&1;then
    [[ "$email" == "1" ]] && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN0PACKETLOSS" != "100%" ]] ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "100%" ]] ;} >/dev/null 2>&1;then
    [[ "$email" == "1" ]] && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN0 Failover Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
[[ "$(nvram get wan1_primary)" == "1" ]] && logger -p 6 -t "${0##*/}" "Debug - Router switched "$WAN1" to Primary WAN"
[[ "$(nvram get wan1_primary)" == "1" ]] && { WAN0STATUS=DISCONNECTED && WANSTATUSMODE=2 && setwanstatus ;} && SWITCHPRIMARY=0 && email=1 && failover && email=0

# Send Email if Connection Loss breaks Failover Monitor Loop
[[ "$(nvram get wan0_primary)" == "1" ]] && { WAN1STATUS=DISCONNECTED && WANSTATUSMODE=2 && setwanstatus ;} && SWITCHPRIMARY=0 && email=1 && failover && email=0

# Return to WAN Status
wanstatus || return
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wan0failbackmonitor"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

logger -p 4 -st "${0##*/}" "WAN0 Failback Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
logger -p 3 -st "${0##*/}" "WAN0 Failback Monitor - Monitoring "$WAN0" via $WAN0TARGET for Restoration"
while [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null 2>&1;do
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan0_gateway)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] && { { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$(nvram get wan0_primary)" == "1" ]] && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} >/dev/null 2>&1;then
      break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} \
  || { { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && { [[ "$(nvram get wan1_gateway)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan1_gw_ifname)" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] && { { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} ;} >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$(nvram get wan0_primary)" == "1" ]] && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
      [[ "$email" == "0" ]] && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] || { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} >/dev/null 2>&1;then
      break
    else
      break
    fi
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] ;} ;} \
  && { [[ "$(nvram get wan1_enable)" == "1" ]] && { [[ "$WAN1PACKETLOSS" == "0%" ]] || [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} ;} >/dev/null 2>&1;then
    [[ "$(nvram get wan1_state_t)" != "2" ]] && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] && email=0
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] \
  || { { [[ "$WAN0PACKETLOSS" == "0%" ]] || [[ "$(nvram get wan0_enable)" == "1" ]] || [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_auxstate_t)" == "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $1}')" == "usb" ]] && { [[ "$(nvram get wan0_is_usb_modem_ready)" == "1" ]] || [ ! -z "$(nvram get wan0_ifname)" ] || [[ "$(nvram get link_wan)" == "1" ]] ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "usb" ]] && { [[ "$(nvram get wan1_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan1_ifname)" ] || [[ "$(nvram get link_wan1)" == "0" ]] ;} ;} ;} ;} >/dev/null 2>&1;then
    WANSTATUSMODE=2 && setwanstatus
    logger -p 6 -t "${0##*/}" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "${0##*/}" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $1}')" == "usb" ]] && { [[ "$(nvram get wan0_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan0_ifname)" ] || [[ "$(nvram get link_wan)" == "0" ]] ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] || { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "usb" ]] && { [[ "$(nvram get wan1_is_usb_modem_ready)" == "0" ]] || [ -z "$(nvram get wan1_ifname)" ] || [[ "$(nvram get link_wan1)" == "0" ]] ;} ;} ;} >/dev/null 2>&1;then
    [[ "$email" == "1" ]] && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN0PACKETLOSS" != "100%" ]] ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "100%" ]] ;} >/dev/null 2>&1;then
    [[ "$email" == "1" ]] && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN0 Failback Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
[[ "$(nvram get wan0_primary)" == "1" ]] && logger -p 6 -t "${0##*/}" "Debug - Router switched "$WAN0" to Primary WAN"
[[ "$(nvram get wan0_primary)" == "1" ]] && { WAN1STATUS=DISCONNECTED && WANSTATUSMODE=2 && setwanstatus ;} && SWITCHPRIMARY=0 && email=1 && failover && email=0

# Return to WAN Status
wanstatus || return
}

# WAN Disabled
wandisabled ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wandisabled"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

wandisabledloop=${wandisabledloop:=1}
[[ "$wandisabledloop" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - WAN Failover is currently disabled.  ***Review Logs***"
DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
while \
  # Reset Loop Iterations if greater than 5 minutes for logging
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($DISABLEDSTARTLOOPTIME+300))" ]] >/dev/null 2>&1;then
    wandisabledloop=1
    DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
  fi
  # WAN Disabled if both interfaces do not have an IP Address or are unplugged
  if { [[ "$(nvram get wan0_auxstate_t)" == "1" ]] || { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_gateway)" ] ;} ;} \
  && { [[ "$(nvram get wan1_auxstate_t)" == "1" ]] || { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_gateway)" ] ;} ;} >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_ipaddr)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" does not have a valid IP: "$(nvram get wan0_ipaddr)""
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_gateway)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$(nvram get wan0_gateway)""
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_ipaddr)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" does not have a valid IP: "$(nvram get wan1_ipaddr)""
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_gateway)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$(nvram get wan1_gateway)""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if an interface is Disabled - Load Balance Mode
  elif [[ "$(nvram get wans_mode)" == "lb" ]] && { [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] ;} >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - Load Balance Mode: "$WAN0" or "$WAN1" is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if WAN0 or WAN1 is a USB Device and is in Ready State but in Cold Standby
  elif { [[ "$(nvram get wans_dualwan | awk '{print $1}')" == "usb" ]] && [[ "$(nvram get wan0_state_t)" != "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(nvram get wan0_is_usb_modem_ready)" == "1" ]] && [[ "$(nvram get link_wan)" == "1" ]] && [ ! -z "$(nvram get wan0_ifname)" ] ;} \
  || { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "usb" ]] && [[ "$(nvram get wan1_state_t)" != "2" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(nvram get wan1_is_usb_modem_ready)" == "1" ]] && [[ "$(nvram get link_wan1)" == "1" ]] && [ ! -z "$(nvram get wan1_ifname)" ] ;} >/dev/null 2>&1;then
    [[ "$(nvram get wan0_is_usb_modem_ready)" == "1" ]] && [[ "$(nvram get wan0_state_t)" != "2" ]] && logger -p 3 -st "${0##*/}" "WAN Failover Disabled - USB Device for "$WAN0" is in Ready State but in Cold Standby"
    [[ "$(nvram get wan1_is_usb_modem_ready)" == "1" ]] && [[ "$(nvram get wan1_state_t)" != "2" ]] && logger -p 3 -st "${0##*/}" "WAN Failover Disabled - USB Device for "$WAN1" is in Ready State but in Cold Standby"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    break
  # WAN Disabled if WAN0 does not have have an IP and WAN1 is Primary - Failover Mode
  elif { { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} && [[ "$(nvram get wan1_primary)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_auxstate_t)" == "1" ]] || { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_ipaddr)" ] ;} || { [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_gateway)" ] ;} ;} >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN1" is Primary"
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_ipaddr)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" does not have a valid IP: "$(nvram get wan0_ipaddr)""
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan0_gateway)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$(nvram get wan0_gateway)""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if WAN1 does not have have an IP and WAN0 is Primary - Failover Mode
  elif { { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} && [[ "$(nvram get wan0_primary)" == "1" ]] ;} \
  && { [[ "$(nvram get wan1_auxstate_t)" == "1" ]] || { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_ipaddr)" ] ;} || { [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_gateway)" ] ;} ;} >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN0" is Primary"
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_ipaddr)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" does not have a valid IP: "$(nvram get wan1_ipaddr)""
    [[ "$wandisabledloop" == "1" ]] && { [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get wan1_gateway)" ] ;} && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$(nvram get wan1_gateway)""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if both interfaces are Enabled and Connected
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { { [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_ipaddr)" ] ;} && { [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan0_gateway)" ] ;} ;} \
  && { [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_ipaddr)" ] ;} && { [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] && [ ! -z "$(nvram get wan1_gateway)" ] ;} ;} ;} >/dev/null 2>&1;then
    [ -z "$(ip route list default table "$WAN0ROUTETABLE" | grep -w "$(nvram get wan0_gw_ifname)")" ] && wanstatus
    [ -z "$(ip route list default table "$WAN1ROUTETABLE" | grep -w "$(nvram get wan1_gw_ifname)")" ] && wanstatus
    [[ "$WAN0PINGPATH" == "1" ]] && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" oif "$(nvram get wan0_gw_ifname)" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ] && wanstatus
    [[ "$WAN0PINGPATH" == "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ] && wanstatus
    [[ "$WAN0PINGPATH" == "3" ]] && [ -z "$(ip route list "$WAN0TARGET" via "$(nvram get wan0_gateway)" dev "$(nvram get wan0_gw_ifname)")" ] && wanstatus
    [[ "$WAN1PINGPATH" == "1" ]] && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" oif "$(nvram get wan1_gw_ifname)" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ] && wanstatus
    [[ "$WAN1PINGPATH" == "2" ]] && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ] && wanstatus
    [[ "$WAN1PINGPATH" == "3" ]] && [ -z "$(ip route list "$WAN1TARGET" via "$(nvram get wan1_gateway)" dev "$(nvram get wan1_gw_ifname)")" ] && wanstatus
    [[ "$wandisabledloop" == "1" ]] && { [[ "$WAN0PINGPATH" == "0" ]] || [[ "$WAN1PINGPATH" == "0" ]] ;} && wanstatus
    [[ "$wandisabledloop" == "1" ]] && logger -p 5 -st "${0##*/}" "WAN Failover Disabled - Pinging "$WAN0TARGET" and "$WAN1TARGET""
    pingtargets || wanstatus
    wan0disabled=${wan0disabled:=$pingfailure0}
    wan1disabled=${wan1disabled:=$pingfailure1}
    [[ "$wandisabledloop" == "1" ]] && [[ "$pingfailure0" == "1" ]] && service "restart_wan_if 0"
    [[ "$wandisabledloop" == "1" ]] && [[ "$pingfailure1" == "1" ]] && service "restart_wan_if 1"
    if { [[ "$pingfailure0" != "$wan0disabled" ]] || [[ "$pingfailure1" != "$wan1disabled" ]] ;} || { [[ "$pingfailure0" == "0" ]] && [[ "$pingfailure1" == "0" ]] ;} >/dev/null 2>&1;then
      [[ "$email" == "0" ]] && email=1
      [[ "$pingfailure0" == "0" ]] && logger -p 4 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is enabled and connected"
      [[ "$pingfailure1" == "0" ]] && logger -p 4 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is enabled and connected"
      [[ "$pingfailure0" != "$wan0disabled" ]] && wandisabledloop="" && wan0disabled=""
      [[ "$pingfailure1" != "$wan1disabled" ]] && wandisabledloop="" && wan1disabled=""
      [[ "$pingfailure0" == "0" ]] && wan0disabled=""
      [[ "$pingfailure1" == "0" ]] && wan1disabled=""
      [[ "$pingfailure0" == "0" ]] && [[ "$pingfailure1" == "0" ]] && wandisabledloop=""
      wanstatus
    elif [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1;then
      wandisabledloop=$(($wandisabledloop+1))
      wanstatus
    else
      [[ "$email" == "1" ]] && email=0
      wandisabledloop=$(($wandisabledloop+1))
      sleep $WANDISABLEDSLEEPTIMER
    fi
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] \
  && { [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] ;} && [[ "$(nvram get wan1_primary)" == "1" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only enabled WAN interface but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && { [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
  && { [[ "$(nvram get wan1_state_t)" == "2" ]] &&  [[ "$(nvram get wan1_auxstate_t)" == "0" ]] ;} && [[ "$(nvram get wan0_primary)" == "1" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only enabled WAN interface but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN. - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { { [[ "$(nvram get wan0_state_t)" == "2" ]] || [[ "$(nvram get wan0_realip_state)" == "2" ]] ;} && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(nvram get wan0_primary)" == "0" ]] ;} \
  && { [[ "$(nvram get wan1_state_t)" != "2" ]] || [[ "$(nvram get wan1_auxstate_t)" != "0" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only connected WAN interface but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN. - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { { [[ "$(nvram get wan1_state_t)" == "2" ]] || [[ "$(nvram get wan1_realip_state)" == "2" ]] ;} && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(nvram get wan1_primary)" == "0" ]] ;} \
  && { [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan0_auxstate_t)" != "0" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only connected WAN interface but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" have 0% packet loss"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} \
  && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] ;} >/dev/null 2>&1;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    wandisabledloop=""
    [[ "$email" == "0" ]] && email=1
    failover && email=0 || return
    break
  # WAN Disabled if WAN0 or WAN1 is not Enabled
  elif [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan0_enable)" == "0" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is Disabled"
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is Disabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Failover Disabled if not in Dual WAN Mode Failover Mode or if ASUS Factory Failover is Enabled
  elif [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - Dual WAN is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && logger -p 2 -st "${0##*/}" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan0_auxstate_t)" == "0" ]] && [[ "$(nvram get wan0_state_t)" != "2" ]] ;} \
  || { [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_auxstate_t)" == "0" ]] && [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan0_state_t)" != "2" ]] && logger -p 1 -st "${0##*/}" "WAN Failover Disabled - Restarting "$WAN0"" && service "restart_wan_if 0"
    [[ "$wandisabledloop" == "1" ]] && [[ "$(nvram get wan1_state_t)" != "2" ]] && logger -p 1 -st "${0##*/}" "WAN Failover Disabled - Restarting "$WAN1"" && service "restart_wan_if 1"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  else
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  fi
>/dev/null 2>&1;do
  wandisabledloop=$(($wandisabledloop+1))
  sleep $WANDISABLEDSLEEPTIMER
done
[ ! -z "$wandisabledloop" ] && wandisabledloop=""
# Return to WAN Status
logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Returning to check WAN Status"

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN Disabled Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# Switch WAN
switchwan ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: switchwan"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

SWITCHPRIMARY=${SWITCHPRIMARY:=1}

# Determine Current Primary WAN and change it to the Inactive WAN
for WANPREFIX in ${WANPREFIXES};do
  if [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "1" ]] && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "${0##*/}" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "0" ]] && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "${0##*/}" "Debug - Active WAN: "${WANPREFIX}""
    continue
  elif [[ "$(nvram get ${WANPREFIX}_primary)" == "0" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "0" ]] && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "${0##*/}" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "1" ]] && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "${0##*/}" "Debug - Active WAN: "${WANPREFIX}""
    continue
  fi
done
# Verify new Active WAN Gateway IP or IP Address are not 0.0.0.0
if { { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "0.0.0.0" ]] || [ -z "$(nvram get "$ACTIVEWAN"_ipaddr)" ] ;} || { [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "0.0.0.0" ]] || [ -z "$(nvram get "$ACTIVEWAN"_gateway)" ] ;} ;} >/dev/null 2>&1;then
  logger -p 1 -st "${0##*/}" "WAN Switch - "$ACTIVEWAN" is disconnected.  IP Address: "$(nvram get "$ACTIVEWAN"_ipaddr)" Gateway IP Address: "$(nvram get "$ACTIVEWAN"_gateway)""
  return
fi
# Perform WAN Switch until Secondary WAN becomes Primary WAN
SWITCHCOMPLETE=0
until { [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] && [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] && [[ "$SWITCHCOMPLETE" == "1" ]] ;} \
&& { [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway)" ]] && [[ "$(echo $(ip route show default | awk '{print $5}'))" == "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] ;} \
&& { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "$(nvram get wan_ipaddr)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "$(nvram get wan_gateway)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" == "$(nvram get wan_gw_ifname)" ]] ;} >/dev/null 2>&1;do
  # Change Primary WAN
  if [[ "$(nvram get "$ACTIVEWAN"_primary)" != "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" != "0" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "1" ]] && logger -p 1 -st "${0##*/}" "WAN Switch - Switching $ACTIVEWAN to Primary WAN"
    nvram set "$ACTIVEWAN"_primary=1 ; nvram set "$INACTIVEWAN"_primary=0
  fi
  # Change WAN IP Address
  if [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" != "$(nvram get wan_ipaddr)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)"
    nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)
  fi

  # Change WAN Gateway
  if [[ "$(nvram get "$ACTIVEWAN"_gateway)" != "$(nvram get wan_gateway)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN Gateway IP: $(nvram get "$ACTIVEWAN"_gateway)"
    nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
  fi
  # Change WAN Gateway Interface
  if [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" != "$(nvram get wan_gw_ifname)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN Gateway Interface: $(nvram get "$ACTIVEWAN"_gw_ifname)"
    nvram set wan_gw_ifname=$(nvram get "$ACTIVEWAN"_gw_ifname)
  fi
  # Change WAN Interface
  if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get wan_ifname)" ]] >/dev/null 2>&1;then
    if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] >/dev/null 2>&1;then
      logger -p 4 -st "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)"
    fi
    nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)
  fi
  
  # Delete Old Default Route
  if [ ! -z "$(nvram get "$INACTIVEWAN"_gw_ifname)" ] && [ ! -z "$(ip route list default via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)")" ] >/dev/null 2>&1;then
    logger -p 5 -st "${0##*/}" "WAN Switch - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)""
    ip route del default \
    && logger -p 4 -st "${0##*/}" "WAN Switch - Deleted default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)"" \
    || logger -p 2 -st "${0##*/}" "WAN Switch - ***Error*** Unable to delete default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)""
  fi

  # Add New Default Route
  if [ ! -z "$(nvram get "$ACTIVEWAN"_gw_ifname)" ] && [ -z "$(ip route list default via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)")" ] >/dev/null 2>&1;then
    logger -p 5 -st "${0##*/}" "WAN Switch - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_gw_ifname) \
    && logger -p 4 -st "${0##*/}" "WAN Switch - Added default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)"" \
    || logger -p 2 -st "${0##*/}" "WAN Switch - ***Error*** Unable to delete default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)""
  fi

  # Change QoS Settings
  for WANPREFIX in ${WANPREFIXES};do
    if [[ "$ACTIVEWAN" != "${WANPREFIX}" ]] >/dev/null 2>&1;then
      continue
    elif [[ "$ACTIVEWAN" == "${WANPREFIX}" ]] >/dev/null 2>&1;then
      getwanparameters || return
      if [[ "$WAN_QOS_ENABLE" == "1" ]] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "WAN Switch - Applying QoS Bandwidth Settings"
        RESTARTSERVICESMODE=${RESTARTSERVICESMODE:=0}
        [[ "$(nvram get qos_enable)" != "1" ]] && { nvram set qos_enable=1 && RESTARTSERVICESMODE=3 && logger -p 6 -t "${0##*/}" "Debug - QoS is Enabled" ;}
        [[ "$(nvram get qos_obw)" != "$WAN_QOS_OBW" ]] && nvram set qos_obw=$WAN_QOS_OBW && RESTARTSERVICESMODE=3
        [[ "$(nvram get qos_ibw)" != "$WAN_QOS_IBW" ]] && nvram set qos_ibw=$WAN_QOS_IBW && RESTARTSERVICESMODE=3
        [[ "$(nvram get qos_overhead)" != "$WAN_QOS_OVERHEAD" ]] && nvram set qos_overhead=$WAN_QOS_OVERHEAD && RESTARTSERVICESMODE=3
        [[ "$(nvram get qos_atm)" != "$WAN_QOS_ATM" ]] && nvram set qos_atm=$WAN_QOS_ATM && RESTARTSERVICESMODE=3
        [[ "$RESTARTSERVICESMODE" == "3" ]] && restartservices
        RESTARTSERVICESMODE=""
      elif [[ "$WAN_QOS_ENABLE" == "0" ]] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "WAN Switch - Disabling QoS Bandwidth Settings"
        [[ "$(nvram get qos_enable)" != "0" ]] && { nvram set qos_enable=0 && STOPQOS=1 && logger -p 6 -t "${0##*/}" "Debug - QoS is Disabled" ;} || STOPQOS=0
        if [[ "$STOPQOS" == "1" ]] >/dev/null 2>&1;then
          logger -p 5 -t "${0##*/}" "WAN Switch - Stopping qos service"
          service stop_qos \
          && logger -p 4 -st "${0##*/}" "WAN Switch - Stopped qos service" \
          || logger -p 2 -st "${0##*/}" "WAN Switch - ***Error*** Unable to stop qos service"
        fi
        STOPQOS=""
      fi
      logger -p 6 -t "${0##*/}" "Debug - Outbound Bandwidth: "$(nvram get qos_obw)""
      logger -p 6 -t "${0##*/}" "Debug - Inbound Bandwidth: "$(nvram get qos_ibw)""
      logger -p 6 -t "${0##*/}" "Debug - QoS Overhead: "$(nvram get qos_overhead)""
      logger -p 6 -t "${0##*/}" "Debug - QoS ATM: "$(nvram get qos_atm)""
      if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null 2>&1;then
        { [[ "$(nvram get qos_obw)" != "0" ]] && [[ "$(nvram get qos_ibw)" != "0" ]] ;} && logger -p 4 -st "${0##*/}" "WAN Switch - Applied Manual QoS Bandwidth Settings"
        [[ "$(nvram get qos_obw)" -ge "1024" ]] && logger -p 4 -st "${0##*/}" "WAN Switch - QoS - Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" \
        || { [[ "$(nvram get qos_obw)" != "0" ]] && logger -p 4 -st "${0##*/}" "WAN Switch - QoS - Upload Bandwidth: $(nvram get qos_obw)Kbps" ;}
        [[ "$(nvram get qos_ibw)" -ge "1024" ]] && logger -p 4 -st "${0##*/}" "WAN Switch - QoS - Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" \
        || { [[ "$(nvram get qos_ibw)" != "0" ]] && logger -p 4 -st "${0##*/}" "WAN Switch - QoS - Download Bandwidth: $(nvram get qos_ibw)Kbps" ;}
        { [[ "$(nvram get qos_obw)" == "0" ]] && [[ "$(nvram get qos_ibw)" == "0" ]] ;} && logger -p 4 -st "${0##*/}" "WAN Switch - QoS - Automatic Settings"
      elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null 2>&1;then
        logger -p 6 -t "${0##*/}" "Debug - QoS is Disabled"
      fi
      break 1
    fi
  done
  sleep 1
  SWITCHCOMPLETE=1
done
if [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] >/dev/null 2>&1;then
  [[ "$SWITCHPRIMARY" == "1" ]] && logger -p 1 -st "${0##*/}" "WAN Switch - Switched $ACTIVEWAN to Primary WAN"
else
  debuglog || return
fi
SWITCHCOMPLETE=""
SWITCHPRIMARY=""

return
}

# Switch DNS
switchdns ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: switchdns"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

# Check if AdGuard is Running or AdGuard Local is Enabled
if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null 2>&1;then
  logger -p 4 -st "${0##*/}" "DNS Switch - DNS is being managed by AdGuard"
  return
fi

for WANPREFIX in ${WANPREFIXES};do

  # Getting WAN Parameters
  getwanparameters || return

  # Switch DNS
  # Check DNS if Status is Connected or Primary WAN
  if { [[ "$STATUS" == "CONNECTED" ]] && [[ "$(nvram get wans_mode)" == "lb" ]] ;} || { [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] ;} >/dev/null 2>&1;then
    # Change Manual DNS Settings
    if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null 2>&1;then
      logger -p 6 -t "${0##*/}" "Debug - Manual DNS Settings for ${WANPREFIX}"
      # Change Manual DNS1 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] >/dev/null 2>&1;then
        if [[ "$(nvram get ${WANPREFIX}_dns1_x)" != "$(nvram get wan_dns1_x)" ]] && { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} >/dev/null 2>&1;then
          logger -p 5 -st "${0##*/}" "DNS Switch - Updating WAN DNS1 Server in NVRAM: "$(nvram get ${WANPREFIX}_dns1_x)""
          nvram set wan_dns1_x=$(nvram get ${WANPREFIX}_dns1_x) \
          && logger -p 4 -st "${0##*/}" "DNS Switch - Updated WAN DNS1 Server in NVRAM: "$(nvram get wan_dns1_x)"" \
          || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to update WAN DNS1 Server in NVRAM: "$(nvram get wan_dns1_x)""
        fi
        if [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns1_x)")" ] >/dev/null 2>&1;then
          logger -p 5 -st "${0##*/}" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)""
          sed -i '1i nameserver '$(nvram get ${WANPREFIX}_dns1_x)'' $DNSRESOLVFILE \
          && logger -p 4 -st "${0##*/}" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)"" \
          || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)""
        fi
      fi
      # Change Manual DNS2 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] >/dev/null 2>&1;then
        if [[ "$(nvram get ${WANPREFIX}_dns2_x)" != "$(nvram get wan_dns2_x)" ]] && { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} >/dev/null 2>&1;then
          logger -p 5 -st "${0##*/}" "DNS Switch - Updating WAN DNS2 Server in NVRAM: "$(nvram get ${WANPREFIX}_dns2_x)""
          nvram set wan_dns2_x=$(nvram get ${WANPREFIX}_dns2_x) \
          && logger -p 4 -st "${0##*/}" "DNS Switch - Updated WAN DNS2 Server in NVRAM: "$(nvram get wan_dns2_x)"" \
          || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to update WAN DNS2 Server in NVRAM: "$(nvram get wan_dns2_x)""
        fi
        if [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns2_x)")" ] >/dev/null 2>&1;then
          logger -p 5 -st "${0##*/}" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)""
          sed -i '2i nameserver '$(nvram get ${WANPREFIX}_dns2_x)'' $DNSRESOLVFILE \
          && logger -p 4 -st "${0##*/}" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)"" \
          || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)""
        fi
      fi

    # Change Automatic ISP DNS Settings
    elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "${0##*/}" "Debug - Automatic DNS Settings from ${WANPREFIX} ISP: "$(nvram get ${WANPREFIX}_dns)""
      if [[ "$(nvram get ${WANPREFIX}_dns)" != "$(nvram get wan_dns)" ]] && { { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} && [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] ;} >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Updating WAN DNS Servers in NVRAM: "$(nvram get ${WANPREFIX}_dns)""
        nvram set wan_dns="$(nvram get ${WANPREFIX}_dns)" \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Updated WAN DNS Servers in NVRAM: "$(nvram get ${WANPREFIX}_dns)"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to update WAN DNS Servers in NVRAM: "$(nvram get ${WANPREFIX}_dns)""
      fi
      # Change Automatic DNS1 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')""
        sed -i '1i nameserver '$(nvram get ${WANPREFIX}_dns | awk '{print $1}')'' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')""

      fi
      # Change Automatic DNS2 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')""
        sed -i '2i nameserver '$(nvram get ${WANPREFIX}_dns | awk '{print $2}')'' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')""
      fi
    fi
  # Check DNS if Status is Disconnected or not Primary WAN
  elif { [[ "$STATUS" != "CONNECTED" ]] && [[ "$(nvram get wans_mode)" == "lb" ]] ;} || { [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$(nvram get ${WANPREFIX}_primary)" == "0" ]] ;} >/dev/null 2>&1;then
    # Remove Manual DNS Settings
    if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null 2>&1;then
      # Remove Manual DNS1 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns1_x)")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)""
        sed -i '/nameserver '$(nvram get ${WANPREFIX}_dns1_x)'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns1_x)""
      fi
      # Change Manual DNS2 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns2_x)")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Removing ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)""
        sed -i '/nameserver '$(nvram get ${WANPREFIX}_dns2_x)'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Removed ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns2_x)""
      fi

    # Remove Automatic ISP DNS Settings
    elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null 2>&1;then
      # Remove Automatic DNS1 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')""
        sed -i '/nameserver '$(nvram get ${WANPREFIX}_dns | awk '{print $1}')'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')""
      fi
      # Remove Automatic DNS2 Server
      if [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')")" ] >/dev/null 2>&1;then
        logger -p 5 -st "${0##*/}" "DNS Switch - Removing ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')""
        sed -i '/nameserver '$(nvram get ${WANPREFIX}_dns | awk '{print $2}')'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "${0##*/}" "DNS Switch - Removed ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')"" \
        || logger -p 2 -st "${0##*/}" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS2 Server: "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')""
      fi
    fi
  fi
done
return
}

# Restart Services
restartservices ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: restartservices"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

# Set Restart Services Mode to Default if not Specified
# Restart Mode 1: Default
# Restart Mode 2: OVPN Server Instances Only
# Restart Mode 3: QoS Engine Only
RESTARTSERVICESMODE=${RESTARTSERVICESMODE:=1}
logger -p 6 -t "${0##*/}" "Debug - Restart Services Mode: "$RESTARTSERVICESMODE""

# Check for services that need to be restarted:
logger -p 6 -t "${0##*/}" "Debug - Checking which services need to be restarted"
SERVICES=""
# Check if dnsmasq is running
if [[ "$RESTARTSERVICESMODE" == "1" ]] && [ ! -z "$(pidof dnsmasq)" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Dnsmasq is running"
  SERVICE="dnsmasq"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if Firewall is Enabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] && [[ "$(nvram get fw_enable_x)" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Firewall is enabled"
  SERVICE="firewall"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if LEDs are Disabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] && [[ "$(nvram get led_disable)" == "0" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - LEDs are enabled"
  SERVICE="leds"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if QoS is Enabled
if { [[ "$RESTARTSERVICESMODE" == "1" ]] || [[ "$RESTARTSERVICESMODE" == "3" ]] ;} && [[ "$(nvram get wans_mode)" != "lb" ]] && [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - QoS is enabled"
  SERVICE="qos"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if IPv6 is using a 6in4 tunnel
if [[ "$RESTARTSERVICESMODE" == "1" ]] && [[ "$(nvram get ipv6_service)" == "6in4" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - IPv6 6in4 is enabled"
  SERVICE="wan6"
  SERVICES="${SERVICES} ${SERVICE}"
fi

# Restart Services
if [ ! -z "$SERVICES" ] >/dev/null 2>&1;then
  for SERVICE in ${SERVICES};do
    logger -p 5 -st "${0##*/}" "Service Restart - Restarting "$SERVICE" service"
    service restart_"$SERVICE" \
    && { logger -p 4 -st "${0##*/}" "Service Restart - Restarted "$SERVICE" service" && continue ;} \
    || { logger -p 2 -st "${0##*/}" "Service Restart - ***Error*** Unable to restart "$SERVICE" service" && continue ;}
  done
SERVICES=""
fi

# Execute YazFi Check
logger -p 6 -t "${0##*/}" "Debug - Checking if YazFi is installed and scheduled in Cron Jobs"
if [[ "$RESTARTSERVICESMODE" == "1" ]] && [ ! -z "$(cru l | grep -w "YazFi")" ] && [ -f "/jffs/scripts/YazFi" ] >/dev/null 2>&1;then
  logger -p 5 -st "${0##*/}" "Service Restart - Executing YazFi Check"
  sh /jffs/scripts/YazFi check \
  && logger -p 4 -st "${0##*/}" "Service Restart - Executed YazFi Check" \
  || logger -p 2 -st "${0##*/}" "Service Restart - ***Error*** Unable to execute YazFi Check"
fi

# Restart OpenVPN Server Instances
if [[ "$RESTARTSERVICESMODE" == "1" ]] || [[ "$RESTARTSERVICESMODE" == "2" ]] >/dev/null 2>&1;then
OVPNSERVERS="
1
2
"

  logger -p 6 -t "${0##*/}" "Debug - Checking if OpenVPN Server instances exist and are enabled"
  for OVPNSERVER in ${OVPNSERVERS};do
    if [ ! -z "$(nvram get vpn_serverx_start | grep -o "$OVPNSERVER")" ] >/dev/null 2>&1;then
      # Restart OVPN Server Instance
      logger -p 5 -st "${0##*/}" "Service Restart - Restarting OpenVPN Server "$OVPNSERVER""
      service restart_vpnserver"$OVPNSERVER" \
      && { logger -p 4 -st "${0##*/}" "Service Restart - Restarted OpenVPN Server "$OVPNSERVER"" && continue ;} \
      || { logger -p 2 -st "${0##*/}" "Service Restart - ***Error*** Unable to restart OpenVPN Server "$OVPNSERVER"" && continue ;}
      sleep 1
    fi
  done
fi

RESTARTSERVICESMODE=""

return
}

# Send Email
sendemail ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: sendemail"

# Check NVRAM
[[ "$CHECKNVRAM" == "1" ]] && { nvramcheck || return ;}

#Email Variables
AIPROTECTION_EMAILCONFIG="/etc/email/email.conf"
SMTP_SERVER="$(awk -F "'" '/SMTP_SERVER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_PORT="$(awk -F "'" '/SMTP_PORT/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
MY_NAME="$(awk -F "'" '/MY_NAME/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
MY_EMAIL="$(awk -F "'" '/MY_EMAIL/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_AUTH_USER="$(awk -F "'" '/SMTP_AUTH_USER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_AUTH_PASS="$(awk -F "'" '/SMTP_AUTH_PASS/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
CAFILE="/rom/etc/ssl/cert.pem"
AMTM_EMAILCONFIG="/jffs/addons/amtm/mail/email.conf"
AMTM_EMAIL_DIR="/jffs/addons/amtm/mail"
TMPEMAILFILE=/tmp/wan-failover-mail
if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
  . "$AMTM_EMAILCONFIG"
fi

# Enable or Disable Email
if [[ "${mode}" == "email" ]] && [ ! -z "$OPTION" ] >/dev/null 2>&1;then
  if [[ "$OPTION" == "enable" ]] >/dev/null 2>&1;then
    SETSENDEMAIL=1
    logger -p 5 -st "${0##*/}" "Email Notification - Email Notifications Enabled"
  elif [[ "$OPTION" == "disable" ]] >/dev/null 2>&1;then
    SETSENDEMAIL=0
    logger -p 5 -st "${0##*/}" "Email Notification - Email Notifications Disabled"
  else
    echo -e "${RED}Invalid Selection!!! Select enable or disable${NOCOLOR}"
    return
  fi
  if [ -z "$(awk -F "=" '/SENDEMAIL/ {print $1}' "$CONFIGFILE")" ] >/dev/null 2>&1;then
    echo -e "SENDEMAIL=" >> $CONFIGFILE
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    killscript
  else
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    killscript
  fi
  return
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Email skipped, System Uptime is less than "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))""
  return
elif [ -f "$AIPROTECTION_EMAILCONFIG" ] || [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then

  # Check for old mail temp file and delete it or create file and set permissions
  logger -p 6 -t "${0##*/}" "Debug - Checking if "$TMPEMAILFILE" exists"
  if [ -f "$TMPEMAILFILE" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - Deleting "$TMPEMAILFILE""
    rm "$TMPEMAILFILE"
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  elif [ ! -f "$TMPEMAILFILE" ] >/dev/null 2>&1;then
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  fi
  
  # Determine Subject Name
  logger -p 6 -t "${0##*/}" "Debug - Selecting Subject Name"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    echo "Subject: WAN Load Balance Failover Notification" >"$TMPEMAILFILE"
  elif [[ "$(nvram get wans_mode)" != "lb" ]] >/dev/null 2>&1;then
    echo "Subject: WAN Failover Notification" >"$TMPEMAILFILE"
  fi

  # Determine From Name
  logger -p 6 -t "${0##*/}" "Debug - Selecting From Name"
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>"$TMPEMAILFILE"
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null 2>&1;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>"$TMPEMAILFILE"
  fi
  echo "Date: $(date -R)" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine Email Header
  logger -p 6 -t "${0##*/}" "Debug - Selecting Email Header"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    echo "***WAN Load Balance Failover Notification***" >>"$TMPEMAILFILE"
  elif [[ "$(nvram get wans_mode)" != "lb" ]] >/dev/null 2>&1;then
    echo "***WAN Failover Notification***" >>"$TMPEMAILFILE"
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"

  # Determine Hostname
  logger -p 6 -t "${0##*/}" "Debug - Selecting Hostname"
  if [[ "$(nvram get ddns_enable_x)" == "1" ]] && [ ! -z "$(nvram get ddns_hostname_x)" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - DDNS Hostname: $(nvram get ddns_hostname_x)"
    echo "Hostname: $(nvram get ddns_hostname_x)" >>"$TMPEMAILFILE"
  elif [ ! -z "$(nvram get lan_hostname)" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - LAN Hostname: $(nvram get lan_hostname)"
    echo "Hostname: $(nvram get lan_hostname)" >>"$TMPEMAILFILE"
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>"$TMPEMAILFILE"

  # Determine Parameters to send based on Dual WAN Mode
  logger -p 6 -t "${0##*/}" "Debug - Selecting Parameters based on Dual WAN Mode: "$(nvram get wans_mode)""
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null 2>&1;then
    # Capture WAN Status and WAN IP Addresses for Load Balance Mode
    logger -p 6 -t "${0##*/}" "Debug - WAN0 IP Address: $(nvram get wan0_ipaddr)"
    echo "WAN0 IPv4 Address: $(nvram get wan0_ipaddr)" >>"$TMPEMAILFILE"
    [ ! -z "$WAN0STATUS" ] && logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN1 IP Address: $(nvram get wan1_ipaddr)"
    echo "WAN1 IPv4 Address: $(nvram get wan1_ipaddr)" >>"$TMPEMAILFILE"
    [ ! -z "$WAN1STATUS" ] && logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - IPv6 IP Address: $(nvram get ipv6_wan_addr)"
    [ ! -z "$(nvram get ipv6_wan_addr)" ] && echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] || [[ "$(nvram get wans_mode)" == "fb" ]] ;} >/dev/null 2>&1;then
    # Capture WAN Status
    [ ! -z "$WAN0STATUS" ] && logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    [ ! -z "$WAN1STATUS" ] && logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"

    # Determine Active ISP
    logger -p 6 -t "${0##*/}" "Debug - Connecting to ipinfo.io for Active ISP"
    ACTIVEISP="$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')"
    [[ ! -z "$ACTIVEISP" ]] && echo "Active ISP: "$ACTIVEISP"" >>"$TMPEMAILFILE" || echo "Active ISP: Unavailable" >>"$TMPEMAILFILE"

    # Determine Primary WAN for WAN IP Address, Gateway IP Address and Interface
    for WANPREFIX in ${WANPREFIXES};do
      [[ "$(nvram get ${WANPREFIX}_primary)" != "1" ]] && continue
      logger -p 6 -t "${0##*/}" "Debug - Primary WAN: "$(nvram get ${WANPREFIX}_primary)""
      echo "Primary WAN: ${WANPREFIX}" >>"$TMPEMAILFILE"
      logger -p 6 -t "${0##*/}" "Debug - WAN IPv4 Address: "$(nvram get ${WANPREFIX}_ipaddr)""
      echo "WAN IPv4 Address: $(nvram get ${WANPREFIX}_ipaddr)" >>"$TMPEMAILFILE"
      logger -p 6 -t "${0##*/}" "Debug - WAN Gateway IP Address: "$(nvram get ${WANPREFIX}_gateway)""
      echo "WAN Gateway IP Address: $(nvram get ${WANPREFIX}_gateway)" >>"$TMPEMAILFILE"
      logger -p 6 -t "${0##*/}" "Debug - WAN Interface: "$(nvram get ${WANPREFIX}_gw_ifname)""
      echo "WAN Interface: $(nvram get ${WANPREFIX}_gw_ifname)" >>"$TMPEMAILFILE"
      [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] && break
    done
    [ ! -z "$(nvram get ipv6_wan_addr)" ] && logger -p 6 -t "${0##*/}" "Debug - IPv6 IP Address: "$(nvram get ipv6_wan_addr)"" && echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"

    # Check if AdGuard is Running or if AdGuard Local is Enabled or Capture WAN DNS Servers
    logger -p 6 -t "${0##*/}" "Debug - Checking if AdGuardHome is running"
    if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null 2>&1;then
      echo "DNS: Managed by AdGuardHome" >>"$TMPEMAILFILE"
    else
      logger -p 6 -t "${0##*/}" "Debug - Checking for Automatic or Manual DNS Settings. WAN DNS Enable: $(nvram get wan_dnsenable_x)"
      for WANPREFIX in ${WANPREFIXES};do
        [[ "$(nvram get ${WANPREFIX}_primary)" != "1" ]] && continue
        if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null 2>&1;then
          logger -p 6 -t "${0##*/}" "Debug - Manual DNS Server 1: $(nvram get ${WANPREFIX}_dns1_x)"
          [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] && echo "DNS Server 1: $(nvram get ${WANPREFIX}_dns1_x)" >>"$TMPEMAILFILE"
          logger -p 6 -t "${0##*/}" "Debug - Manual DNS Server 2: $(nvram get ${WANPREFIX}_dns2_x)"
          [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] && echo "DNS Server 2: $(nvram get ${WANPREFIX}_dns2_x)" >>"$TMPEMAILFILE"
        elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null 2>&1;then
          logger -p 6 -t "${0##*/}" "Debug - Automatic DNS Servers: $(nvram get ${WANPREFIX}_dns)"
          [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $1}')" ] && echo "DNS Server 1: $(nvram get ${WANPREFIX}_dns | awk '{print $1}')" >>"$TMPEMAILFILE"
          [ ! -z "$(nvram get ${WANPREFIX}_dns | awk '{print $2}')" ] && echo "DNS Server 2: $(nvram get ${WANPREFIX}_dns | awk '{print $2}')" >>"$TMPEMAILFILE"
        fi
        [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] && break
      done
    fi
    logger -p 6 -t "${0##*/}" "Debug - QoS Enabled Status: $(nvram get qos_enable)"
    if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null 2>&1;then
      echo "QoS Status: Enabled" >>"$TMPEMAILFILE"
      if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_ibw)" ]] >/dev/null 2>&1;then
        logger -p 6 -t "${0##*/}" "Debug - QoS Outbound Bandwidth: $(nvram get qos_obw)"
        logger -p 6 -t "${0##*/}" "Debug - QoS Inbound Bandwidth: $(nvram get qos_ibw)"
        if [[ "$(nvram get qos_obw)" == "0" ]] && [[ "$(nvram get qos_ibw)" == "0" ]] >/dev/null 2>&1;then
          echo "QoS Mode: Automatic Settings" >>"$TMPEMAILFILE"
        else
          echo "QoS Mode: Manual Settings" >>"$TMPEMAILFILE"
          [[ "$(nvram get qos_ibw)" -gt "1024" ]] && echo "QoS Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Download Bandwidth: $(nvram get qos_ibw)Kbps" >>"$TMPEMAILFILE"
          [[ "$(nvram get qos_obw)" -gt "1024" ]] && echo "QoS Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Upload Bandwidth: $(nvram get qos_obw)Kbps" >>"$TMPEMAILFILE"
          logger -p 6 -t "${0##*/}" "Debug - QoS WAN Packet Overhead: $(nvram get qos_overhead)"
          echo "QoS WAN Packet Overhead: $(nvram get qos_overhead)" >>"$TMPEMAILFILE"
        fi
      fi
    elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null 2>&1;then
      echo "QoS Status: Disabled" >>"$TMPEMAILFILE"
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine whether to use AMTM or AIProtection Email Configuration
  logger -p 6 -t "${0##*/}" "Debug - Selecting AMTM or AIProtection for Email Notification"
  e=0
  if [ -f "$AMTM_EMAILCONFIG" ] && [ "$e" == "0" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - AMTM Email Configuration Detected"
    if [ -z "$FROM_ADDRESS" ] || [ -z "$TO_NAME" ] || [ -z "$TO_ADDRESS" ] || [ -z "$USERNAME" ] || [ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ] || [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] >/dev/null 2>&1;then
      logger -p 2 -st "${0##*/}" "Email Notification - AMTM Email Configuration Incomplete"
    else
	$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file "$TMPEMAILFILE" \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG) \
		&& $(rm "$TMPEMAILFILE" & logger -p 4 -st "${0##*/}" "Email Notification - Email Notification via amtm Sent") && e=$(($e+1)) \
                || $(rm "$TMPEMAILFILE" & logger -p 2 -st "${0##*/}" "Email Notification - Email Notification via amtm Failed")
    fi
  fi
  if [ -f "$AIPROTECTION_EMAILCONFIG" ] && [ "$e" == "0" ] >/dev/null 2>&1;then
    logger -p 6 -t "${0##*/}" "Debug - AIProtection Alerts Email Configuration Detected"
    if [ ! -z "$SMTP_SERVER" ] && [ ! -z "$SMTP_PORT" ] && [ ! -z "$MY_NAME" ] && [ ! -z "$MY_EMAIL" ] && [ ! -z "$SMTP_AUTH_USER" ] && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null 2>&1;then
      $(cat "$TMPEMAILFILE" | sendmail -w $EMAILTIMEOUT -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL") \
      && $(rm "$TMPEMAILFILE" & logger -p 4 -st "${0##*/}" "Email Notification - Email Notification via AIProtection Alerts Sent") && e=$(($e+1)) \
      || $(rm "$TMPEMAILFILE" & logger -p 2 -st "${0##*/}" "Email Notification - Email Notification via AIProtection Alerts Failed")
    else
      logger -p 2 -st "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
  e=""
elif [ ! -f "$AIPROTECTION_EMAILCONFIG" ] || [ ! -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Email Notifications are not configured"
fi
return
}

# Delay if NVRAM is not accessible
nvramcheck ()
{
CHECKNVRAM=${CHECKNVRAM:=1}
[[ "$CHECKNVRAM" == "0" ]] && return

logger -p 6 -t "${0##*/}" "Debug - Function: nvramcheck"

if [ -z "$(nvram get model)" ] >/dev/null 2>&1;then
  logger -p 1 -st "${0##*/}" "***NVRAM Inaccessible***"
  NVRAMTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+5))"
  while [ -z "$(nvram get model)" ] && [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$NVRAMTIMEOUT" ]] >/dev/null 2>&1;do
    if tty >/dev/null 2>&1;then
      TIMEOUTTIMER=$(($NVRAMTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
      printf '\033[K%b\r' ""${BOLD}""${RED}"***Waiting for NVRAM Access*** Timeout: "$TIMEOUTTIMER" Seconds"${NOCOLOR}""
    fi
    sleep 1
  done
  return
fi
logger -p 6 -t "${0##*/}" "Debug - ***NVRAM Check Passed***"
return
}

# Debug Logging
debuglog ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: debuglog"

# Delay if NVRAM is not accessible
nvramcheck || return

if [[ "$(nvram get log_level)" -ge "7" ]] >/dev/null 2>&1;then
  logger -p 6 -t "${0##*/}" "Debug - Model: "$(nvram get model)""
  logger -p 6 -t "${0##*/}" "Debug - Product ID: "$(nvram get productid)""
  logger -p 6 -t "${0##*/}" "Debug - Build Name: "$(nvram get build_name)""
  logger -p 6 -t "${0##*/}" "Debug - Firmware: "$(nvram get buildno)""
  logger -p 6 -t "${0##*/}" "Debug - IPRoute Version: "$(ip -V | awk -F "-" '{print $2}')""
  logger -p 6 -t "${0##*/}" "Debug - WAN Capability: "$(nvram get wans_cap)""
  logger -p 6 -t "${0##*/}" "Debug - Dual WAN Mode: "$(nvram get wans_mode)""
  logger -p 6 -t "${0##*/}" "Debug - Load Balance Ratio: "$(nvram get wans_lb_ratio)""
  logger -p 6 -t "${0##*/}" "Debug - Dual WAN Interfaces: "$(nvram get wans_dualwan)""
  logger -p 6 -t "${0##*/}" "Debug - ASUS Factory Watchdog: "$(nvram get wandog_enable)""
  logger -p 6 -t "${0##*/}" "Debug - JFFS custom scripts and configs: "$(nvram get jffs2_scripts)""
  logger -p 6 -t "${0##*/}" "Debug - HTTP Web Access: "$(nvram get misc_http_x)""
  logger -p 6 -t "${0##*/}" "Debug - Firewall Enabled: "$(nvram get fw_enable_x)""
  logger -p 6 -t "${0##*/}" "Debug - IPv6 Firewall Enabled: "$(nvram get ipv6_fw_enable)""
  logger -p 6 -t "${0##*/}" "Debug - LEDs Disabled: "$(nvram get led_disable)""
  logger -p 6 -t "${0##*/}" "Debug - QoS Enabled: "$(nvram get qos_enable)""
  logger -p 6 -t "${0##*/}" "Debug - DDNS Enabled: "$(nvram get ddns_enable_x)""
  logger -p 6 -t "${0##*/}" "Debug - DDNS Hostname: "$(nvram get ddns_hostname_x)""
  logger -p 6 -t "${0##*/}" "Debug - LAN Hostname: "$(nvram get lan_hostname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN IPv6 Service: "$(nvram get ipv6_service)""
  logger -p 6 -t "${0##*/}" "Debug - WAN IPv6 Address: "$(nvram get ipv6_wan_addr)""
  logger -p 6 -t "${0##*/}" "Debug - Default Route: "$(ip route list default table main)""
  logger -p 6 -t "${0##*/}" "Debug - OpenVPN Server Instances Enabled: "$(nvram get vpn_serverx_start)""
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    getwanparameters || return

    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Enabled: "$(nvram get ${WANPREFIX}_enable)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Routing Table Default Route: "$(ip route list default table "$TABLE")""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Ping Path: "$PINGPATH""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Rule: "$(ip rule list from all iif lo to "$TARGET" lookup "$TABLE")""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Route: "$(ip route list "$TARGET" via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)")""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" IP Address: "$(nvram get ${WANPREFIX}_ipaddr)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Real IP Address: "$(nvram get ${WANPREFIX}_realip_ip)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Real IP Address State: "$(nvram get ${WANPREFIX}_realip_state)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Gateway IP: "$(nvram get ${WANPREFIX}_gateway)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Gateway Interface: "$(nvram get ${WANPREFIX}_gw_ifname)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Interface: "$(nvram get ${WANPREFIX}_ifname)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Automatic ISP DNS Enabled: "$(nvram get ${WANPREFIX}_dnsenable_x)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Automatic ISP DNS Servers: "$(nvram get ${WANPREFIX}_dns)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Manual DNS Server 1: "$(nvram get ${WANPREFIX}_dns1_x)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Manual DNS Server 2: "$(nvram get ${WANPREFIX}_dns2_x)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" State: "$(nvram get ${WANPREFIX}_state_t)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Aux State: "$(nvram get ${WANPREFIX}_auxstate_t)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Sb State: "$(nvram get ${WANPREFIX}_sbstate_t)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Primary Status: "$(nvram get ${WANPREFIX}_primary)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" USB Modem Status: "$(nvram get ${WANPREFIX}_is_usb_modem_ready)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" UPnP Enabled: "$(nvram get ${WANPREFIX}_upnp_enable)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" NAT Enabled: "$(nvram get ${WANPREFIX}_nat_x)""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Target IP Address: "$TARGET""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Routing Table: "$TABLE""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" IP Rule Priority: "$PRIORITY""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Mark: "$MARK""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Mask: "$MASK""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" From WAN Priority: "$FROMWANPRIORITY""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" To WAN Priority: "$TOWANPRIORITY""
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" OVPN WAN Priority: "$OVPNWANPRIORITY""
  done
fi
return
}
scriptmode
