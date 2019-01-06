#!/bin/sh

basename $0 | tr '[:lower:]' '[:upper:]'
echo


pp=$(dirname "$0")
test -f "$pp/functions" && {
    . "$pp/functions";
} || {
    echo 'ERROR: functions not found!' >&2;
    echo;
    exit 1;
}

set_root "$@"
cfg_dir="$root/etc/httpd"


echo "root: $root/"
move_on
echo


test -f $cfg_dir/httpd.conf || {
    echo 'ERROR: httpd.conf not found! >&2';
    echo;
    exit 1;
}
test -f $cfg_dir/original/httpd.conf -a "`cat $cfg_dir/original/httpd.conf | md5sum`" = "`cat $cfg_dir/httpd.conf| md5sum`" || {
    echo 'Warning: httpd.conf != original/httpd.conf!'
    move_on
}
test -f $cfg_dir/mod_php.conf -a -f $cfg_dir/original/mod_php.conf && test "`cat $cfg_dir/mod_php.conf | md5sum`" = "`cat $cfg_dir/original/mod_php.conf | md5sum`" || {
    echo 'Warning: mod_php.conf != original/mod_php.conf!'
    move_on
}


echo 'Backup httpd.conf'
cp $cfg_dir/httpd.conf $cfg_dir/httpd.conf.bac


mkdir -p $cfg_dir/mods-available
rm -f $cfg_dir/mods-available/* 2>/dev/null
mkdir -p $cfg_dir/mods-enabled
rm -f $cfg_dir/mods-enabled/* 2>/dev/null
mkdir -p $cfg_dir/vhosts


#httpd_conf=()
#while read httpd_conf_line; do httpd_conf[${#httpd_conf[@]}]="$httpd_conf_line"; done < $cfg_dir/httpd.conf
readarray httpd_conf < $cfg_dir/httpd.conf


echo 'Reconfig mods..'

IFS_OLD=$IFS
IFS='
';
mods=( `find $root/usr/lib64/httpd/modules/ -name *.so` )
IFS=$IFS_OLD

for mod in "${mods[@]}"; do
    mod=${mod/$root/}
    mod_filename=${mod##*/}

    test $mod_filename = libphp5.so && {
        mod_name=php5
    } || {
        mod_name=${mod_filename:4:(-3)}
    }

    echo "- $mod_name ($mod)"
    echo "LoadModule ${mod_name}_module $mod" > $cfg_dir/mods-available/$mod_name.load
done

for i in "${!httpd_conf[@]}"; do
    httpd_conf_line=${httpd_conf[$i]}
    test -n "`echo $httpd_conf_line | grep 'LoadModule'`" && unset httpd_conf[$i]
done

echo


echo 'Moving & edit original confs..'

confs=(
    'mod_php.conf' 'php5.conf'
    'extra/httpd-autoindex.conf' 'autoindex.conf'
    'extra/httpd-info.conf' 'info.conf'
    'extra/httpd-info.conf' 'status.conf'
    'extra/httpd-ssl.conf' 'ssl.conf'
    'extra/httpd-userdir.conf' 'userdir.conf'
    'extra/proxy-html.conf' 'proxy_html.conf'
)
for i in 0 2 4 6 8 10 12; do
    src="${confs[$i]}"
    dst="${confs[$i+1]}"
    echo -n "$src -> mods-available/$dst :: "
    test -f "$cfg_dir/$src" && cp $cfg_dir/$src $cfg_dir/mods-available/$dst 2>/dev/null && {
        echo ok;
        vi_file "$cfg_dir/mods-available/$dst";
    } || {
        echo 'ERROR (not found)!';
        move_on;
    }
done
for i in 0 2 4 6 8 10 12; do
    test -f "$cfg_dir/${confs[$i]}" && rm "$cfg_dir/${confs[$i]}"
done

src='extra/httpd-vhosts.conf'
dst='vhosts/httpd-default'
echo -n "$src -> $dst :: "
test -f "$cfg_dir/$src" && mv $cfg_dir/$src $cfg_dir/$dst 2>/dev/null && {
    echo ok;
} || {
    echo 'ERROR (not found)!';
    move_on;
}
echo "Include $cfg_dir/vhosts/*" > $cfg_dir/mods-available/vhost_alias.conf

echo 'Extract modules configurations from httpd.conf..'
for mod in 'unixd' 'dir' 'log_config' 'alias' 'cgid' 'headers' 'mime'; do
    echo "- searching for $mod.."

    mod_start=''
    mod_stop=''
    mod_conf=''
    for i in "${!httpd_conf[@]}"; do
        line=${httpd_conf[$i]}
        test -z "$mod_start" && {
            mod_start=`echo "$line" | grep -Pi "IfModule\s+$mod"`;
            test -z "$mod_start" && continue;
        }

        echo $line;
        mod_conf="$mod_conf$line\n"
        unset httpd_conf[$i]

        mod_stop=`echo "$line" | grep -Pi "/IfModule"`;
        test -z "$mod_stop" && continue;
        stty -echo
        read -e -n1 -p 'continue (or is this the end of module) y/*?' yn;
        stty echo
        echo -en "\r               \r"
        test "$yn" != 'y' && break
    done

    test -z "$mod_conf" && {
        echo "ERROR (mod $mod not found)!";
        move_on;
    } || {
        echo -en $mod_conf > $cfg_dir/mods-available/$mod.conf;
        test "$mod" = 'dir' && echo -e "\n<IfModule php5>\n    DirectoryIndex index.php index.html\n</IfModule>" >> $cfg_dir/mods-available/$mod.conf;
        vi_file "$cfg_dir/mods-available/$mod.conf";
    }

    echo
done


echo 'Update httpd.conf'
echo -e "# Dynamic Shared Object (DSO) Support\n# Debian like.. ;)\nInclude /etc/httpd/mods-enabled/*.load\nInclude /etc/httpd/mods-enabled/*.conf" > "$cfg_dir/httpd.conf"
for i in "${!httpd_conf[@]}"; do
    echo -en "${httpd_conf[$i]}" >> "$cfg_dir/httpd.conf"
done
vi_file "$cfg_dir/httpd.conf"
