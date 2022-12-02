#!/bin/bash
KEY=$RANDOM
export KEY1=$RANDOM
export KEY2=$RANDOM
export fpipe_list_user=$(mktemp -u --tmpdir find.XXXXXXXX)
export temp=$(mktemp -u --tmpdir find.XXXXXXXX) #file luu ten nguoi dung de truyen vao ham xoa
echo "null" >>$temp
mkfifo "$fpipe_list_user"
trap "rm -f $fpipe_list_user" EXIT
trap "rm -f $temp" EXIT
get_all_user() {
	echo -e '\f' >>"$fpipe_list_user"
	alluser=$(cat /etc/passwd | awk -F: '$7=="/bin/bash" {print $1"\\n"$3"\\n"$4"\\n"}' | tr -d '[:space:]')
	echo -e $alluser >$fpipe_list_user
}
get_selected_user() {
	echo -e '\f' >$temp
	echo "$1" >$temp
	cat $temp
}
show_user() {
	yad --center --form --text="Them user" \
		--field="UserName" '' --field="Password:H" '' --field="Type:CB" "Standard!^Administrative" &
}
dialog_add_user() {
	yad --form --text="Add user" --borders=20 --no-buttons --center --width=300 --height=350 \
		--field="UserName" '' --field="Password:H" '' --field="Type:CB" "Standard!^Administrative" \
		--field="Add:FBTN" 'bash -c "add_user %1 %2 %3" ' &
}
dialog_update_user() {
	selected_user=$(cat $temp)
	user_exists=$(getent passwd "$selected_user")
	if [ -z "$user_exists" ]; then
		yad --image "dialog-warning" --title "Thong bao" --center --button=gtk-ok:0 \
			--text "Vui long chon user"
	else
		KEY2=$RANDOM

		yad --plug=$KEY2 --tabnum=1 --form --width=600 --height=450 --button="gtk-close:1" \
			--field="New user name" '' --field="OK:FBTN" 'bash -c "changing_user_name %1"' &

		yad --plug=$KEY2 --tabnum=2 --form \
			--field="New password" '' --field="Confirmation" '' --field="OK:FBTN" 'bash -c "changing_password %1 %2"' &
		list_group=$(getent group | awk -F: {'print $1"!"}' | tr -d '[:space:]')
		yad --plug=$KEY2 --tabnum=3 --form --field="Type:CB" "$list_group" \
			--field="OK:FBTN" 'bash -c "changing_group_user %1" ' &

		# main dialog
		yad --notebook --borders=20 --center --width=600 --height=450 --title="Quan ly users group" --button="gtk-close:1" \
			--key=$KEY2 --tab="Change User Name" --tab="Change Password" --tab="Change Group"

	fi
}
dialog_manage_group() {
	export fpipe_list_group=$(mktemp -u --tmpdir find.XXXXXXXX)
	mkfifo "$fpipe_list_group"
	trap "rm -f $fpipe_list_group" EXIT
	exec 4<>$fpipe_list_group

	dialog_add_group() {
		export fpipe_list_Ugroup=$(mktemp -u --tmpdir find.XXXXXXXX)
		mkfifo "$fpipe_list_Ugroup"
		trap "rm -f $fpipe_list_Ugroup" EXIT
		exec 6<>$fpipe_list_Ugroup
		export fpipe_list_USgroup=$(mktemp -u --tmpdir find.XXXXXXXX)
		mkfifo "$fpipe_list_USgroup"
		trap "rm -f $fpipe_list_USgroup" EXIT
		exec 5<>$fpipe_list_USgroup
		get_all_userg() {
			echo -e '\f' >>"$fpipe_list_Ugroup"
			alluser=$(cat /etc/passwd | awk -F: '$7=="/bin/bash" {print "FALSE\\n"$1"\\n"}' | tr -d '[:space:]')
			echo -e $alluser >$fpipe_list_Ugroup
		}
		get_selected_userg(){
			echo -e $2"," >>$fpipe_list_USgroup
		}
		add_group(){
			groupadd $1
			list_user=$(cat $fpipe_list_USgroup | tr -d '[:space:]')
			echo $list_user
			for u in {$list_user}; do usermod -aG $1 $u; done
		}
		export -f get_all_userg add_group get_selected_userg
		get_all_userg

		yad --plug=$KEY2 --tabnum=1 --form --columns=3 --text="  " \
			--field="Group Name" '' --field="OK:FBTN" 'bash -c "add_group %1"' &

		yad --plug=$KEY2 --tabnum=2 --width=600 --height=450 --expand-column=0 --button="gtk-close:1" \
			--list --checklist --select-action='bash -c "get_selected_userg %s %s "' --column="Select" --column="Users" <&6 &
		
		yad --paned --borders=20 --center --width=600 --height=450 --title="Quan ly group" --button="gtk-cancle:0" \
			--key=$KEY2 --tab="ListGroup" --tab="Feature"
	}

	get_all_group() {
		echo -e '\f' >>"$fpipe_list_group"
		allGroup=$(getent group | awk -F: ' {if($4 == "") $4="null"; print $1"\\n"$3"\\n"$4"\\n"}' | tr -d '[:space:]')
		echo -e $allGroup >$fpipe_list_group
	}
	export -f get_all_group dialog_add_group
	get_all_group

	yad --plug=$KEY1 --tabnum=1 --width=600 --height=450 --expand-column=0 --button="gtk-close:1" \
		--list --select-action='bash -c "get_selected_user %s %s %s"' --column="GroupName" --column="GID" --column="Users" <&4 &
	yad --plug=$KEY1 --tabnum=2 --form --columns=3 --text="  " \
		--field="Add:FBTN" 'bash -c dialog_add_group' --field="Update:FBTN" '' --field="Delete:FBTN" '' &
	yad --paned --borders=20 --center --splitter=300 --width=600 --height=450 --title="Quan ly group" --button="gtk-close:1" \
		--key=$KEY1 --tab="ListGroup" --tab="Feature"
}
add_user() {
	if [ $(id -u) -eq 0 ]; then
		egrep "^$1" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			yad --image "dialog-warning" --width=300 --height=150 --center --title "Thong bao" --button=gtk-ok:0 \
				--text "User $1 da ton tai!"
		else
			pass=$(perl -e 'print crypt($ARGV[0], "password")' $2)
			useradd -m -s /bin/bash -p "$pass" "$1"
			if [ "$3"="Administrative" ]; then
				sudo usermod -aG sudo "$1"
			fi
			if [ $? -eq 0 ]; then

				yad --image "dialog-message" --center --title "Thong bao" --button=gtk-ok:0 \
					--text "Them user thanh cong"
				get_all_user
			else
				yad --image "dialog-warning" --title "Thong bao" --button=gtk-ok:0 \
					--text "Them user that bai"
			fi
		fi
	else
		yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
			--text "Vui long su dung tai khoan root de them user"
	fi
}
changing_user_name() {
	selected_user=$(cat $temp)
	user_exists=$(getent passwd "$selected_user")
	if [ -z "$user_exists" ]; then
		yad --image "dialog-warning" --title "Thong bao" --center --button=gtk-ok:0 \
			--text "Vui long chon user"
	else
		sudo chfn -f "$1" $selected_user >/dev/null
		if [ $? -eq 0 ]; then
			yad --image "dialog-message" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Chinh sua user name thanh cong"
			echo -e '\f' >$temp
		else
			yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Da xay ra loi"
		fi
	fi
}
changing_password() {
	selected_user=$(cat $temp)
	user_exists=$(getent passwd "$selected_user")
	if [ "$1" != "$2" ]; then
		yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
			--text "Password khong trung khop"
	else
		if [ -z "$user_exists" ]; then
			yad --image "dialog-warning" --title "Thong bao" --center --button=gtk-ok:0 \
				--text "Vui long chon user"
		else
			echo -e "$1\n$2" | (passwd $selected_user) >/dev/null
			if [ $? -eq 0 ]; then
				yad --image "dialog-message" --center --title "Thong bao" --button=gtk-ok:0 \
					--text "Chinh sua password thanh cong"
				echo -e '\f' >$temp
			else
				yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
					--text "Da xay ra loi"
			fi
		fi
	fi
}
changing_group_user() {
	selected_user=$(cat $temp)
	user_exists=$(getent passwd "$selected_user")
	if [ -z "$user_exists" ]; then
		yad --image "dialog-warning" --title "Thong bao" --center --button=gtk-ok:0 \
			--text "Vui long chon user"
	else
		usermod -g $1 $selected_user >/dev/null
		if [ $? -eq 0 ]; then
			yad --image "dialog-message" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Chinh sua group thanh cong"
			echo -e '\f' >$temp
			get_all_user
		else
			yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Da xay ra loi"
		fi
	fi
}
del_user() {
	selected_user=$(cat $temp)
	user_exists=$(getent passwd "$selected_user")
	if [ -z "$user_exists" ]; then
		yad --image "dialog-warning" --title "Thong bao" --center --button=gtk-ok:0 \
			--text "Vui long chon user"
	else
		userdel -r $selected_user >/dev/null
		if [ $? -eq 0 ]; then
			yad --image "dialog-message" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Xoa user thanh cong"
			echo -e '\f' >$temp
			get_all_user
		else
			yad --image "dialog-warning" --center --title "Thong bao" --button=gtk-ok:0 \
				--text "Da xay ra loi"
		fi
	fi

}
export -f add_user get_all_user show_user dialog_add_user get_selected_user del_user dialog_manage_group dialog_update_user changing_user_name changing_password changing_group_user
exec 3<>$fpipe_list_user

get_all_user
# List user tab
yad --plug=$KEY --tabnum=1 --width=600 --height=450 --expand-column=0 --button="gtk-close:1" --limit=5 \
	--list --select-action='bash -c "get_selected_user %s %s %s"' --column="Username" --column="UID" --column="GID" <&3 &

# Feature tab
yad --plug=$KEY --tabnum=2 --form --columns=4 --text="  " \
	--field="Add:FBTN" 'bash -c dialog_add_user' --field="Update:FBTN" 'bash -c dialog_update_user' --field="Delete:FBTN" 'bash -c del_user' --field="Manage Groups:FBTN" 'bash -c dialog_manage_group' &

# main dialog
yad --paned --borders=20 --center --splitter=300 --width=600 --height=450 --title="Quan ly users group" --button="gtk-close:1" \
	--key=$KEY --tab="ListUser" --tab="Feature"

exec 3>&-
