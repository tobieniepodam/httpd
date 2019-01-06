#!/bin/sh

pp=$(dirname "$0")
test -f "$pp/functions" && {
    . "$pp/functions";
} || {
    echo 'ERROR: file functions not found!' >&2;
    echo;
    exit 1;
}

get_path 'Base path to crt/key/csr files:'
if [ "${path:(-1)}" = '.' ]; then
    path="${path:0:(-1)}"
fi

key="${path}.key"
echo -n "$key "
if [ -f "$key" ]; then
    openssl rsa -noout -modulus -in "$key" | openssl md5
else
    echo not found!
fi

key="${path}.csr"
echo -n "$key "
if [ -f "$key" ]; then
    openssl req -noout -modulus -in "$key" | openssl md5
else
    echo not found!
fi

key="${path}.crt"
echo -n "$key "
if [ -f "$key" ]; then
    openssl x509 -noout -modulus -in "$key" | openssl md5
else
    echo not found!
fi


