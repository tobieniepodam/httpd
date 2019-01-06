#!/bin/sh

basename $0 | tr '[:lower:]' '[:upper:]'
echo


pp=$(dirname "$0")
test -f "$pp/functions" && {
    . "$pp/functions";
    } || {
    echo 'ERROR: file functions not found!' >&2;
    echo;
    exit 1;
}

set_root "$@"
cfg_dir="$root/etc/httpd"


echo "root: $root/"
move_on
echo


IFS_OLD=$IFS
IFS='
';
mods=( `find $root/etc/httpd/mods-available/ -name *.load 2>/dev/null | sort` )
IFS=$IFS_OLD

test -z "$mods" && {
    echo 'ERROR: no modules found' >&2;
    exit 1;
}

dialog_choices=''
for mod in "${mods[@]}"; do
  mod_name=${mod##*/}
  mod_name=${mod_name%.load}
  test -f $root/etc/httpd/mods-enabled/$mod_name.load && mod_enabled=on || mod_enabled=off
  dialog_choices="$dialog_choices $mod_name module $mod_enabled"
done

mods_enabled=$(dialog --separate-output --checklist "Select apache modules:" 22 76 16 $dialog_choices 2>&1 >/dev/tty)
test "$?" = 0 || { clear; exit; }
clear

rm $cfg_dir/mods-enabled/* 2>/dev/null
for mod_enabled in $mods_enabled; do
    ln -s ../mods-available/$mod_enabled.load $cfg_dir/mods-enabled/$mod_enabled.load
    test -f $cfg_dir/mods-available/$mod_enabled.conf && ln -s ../mods-available/$mod_enabled.conf $cfg_dir/mods-enabled/$mod_enabled.conf
done

