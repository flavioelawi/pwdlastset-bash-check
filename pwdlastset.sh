#!/bin/bash
bind_user="***************"
ldap_server="******************"
bind_pass="*********"
max_pwd_expiration="90"
from_mail_address="***********"
bcc_mail_address="**************"
zimbra_domain_tocheck="*******"
reset_password_page="**********"
# cerca solo gli utenti in Users, che siano di classe user e che abbiano l'attributo email

while read utente 
	do
	base_search="dc=contoso,dc=com sAMAccountName=$utente mail"
	timestamp=`date +%s`

	### ottieni l'attributo pwdlastset da AD

        ad_pwdlastset=`/opt/zimbra/bin/ldapsearch -LLL -D $bind_user -w $bind_pass -h $ldap_server -b $base_search pwdLastSet | grep -i pwdLastSet: | cut -c 13-`

        if [[ -z "$ad_pwdlastset" ]]; 
	then
		echo "no pwdlastset"
	else
		if [[ $ad_pwdlastset -lt 0 ]];
		then
			echo "valore pwdLastSet non valido, salto utente"
		else
		
			### converti ad_pwdlastset in unix time (epoch) -> epoch_pwdlastset
			epoch_pwdlastset=$((($ad_pwdlastset/10000000)-11644473600))
			epoch_days=$(($timestamp-$epoch_pwdlastset)) #calcola in epoch la differenza tra l'esecuzione di questo ciclo e l'ultimo cambio password
			days_difference=$(($epoch_days/86400))  #converte la differenza in giorni
			if [[ $days_difference -gt $max_pwd_expiration ]];
			then
				echo "la password ha superato i $max_pwd_expiration giorni, potrebbe non scadere o non ha cambiato password nel tempo limite"
			else			
			days_remaining=$(($max_pwd_expiration-$days_difference))
				if [[ $days_difference -gt 75 ]];
				then
					mail_address=`/opt/zimbra/bin/ldapsearch -LLL -D $bind_user -w $bind_pass -h $ldap_server -b $base_search mail | grep -i mail: | cut -c 7-`
					/usr/local/bin/sendEmail -f $from_mail_address -t $mail_address -bcc $bcc_mail_address -u "Avviso scadenza password domain" -m "la password di $mail_address sta per scadere entro $days_remaining giorni, si consiglia di cambiarla andando su $reset_password_page , usando come nome utente $utente ; la password deve avere minimo di 8 caratteri, con una lettera maiuscola ed almeno un numero." -o tls=no
				else
					echo "non sta scadendo"
				fi
			fi		
		fi
	fi
done < <(/opt/zimbra/bin/zmprov -l gaa $zimbra_domain_tocheck | cut -d @ -f1)
