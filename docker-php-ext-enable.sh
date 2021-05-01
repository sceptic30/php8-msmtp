#!/bin/sh
set -e

extDir="$(php -d 'display_errors=stderr' -r 'echo ini_get("extension_dir");')"
cd "$extDir"

usage() {
	echo "usage: $0 [options] module-name [module-name ...]"
	echo "   ie: $0 gd mysqli"
	echo "       $0 pdo pdo_mysql"
	echo "       $0 --ini-name 0-apc.ini apcu apc"
	echo
	echo 'Possible values for module-name:'
	find -maxdepth 1 \
			-type f \
			-name '*.so' \
			-exec basename '{}' ';' \
		| sort \
		| xargs
	echo
	echo 'Some of the above modules are already compiled into PHP; please check'
	echo 'the output of "php -i" to see which modules are already loaded.'
}

opts="$(getopt -o 'h?' --long 'help,ini-name:' -- "$@" || { usage >&2 && false; })"
eval set -- "$opts"

iniName=
while true; do
	flag="$1"
	shift
	case "$flag" in
		--help|-h|'-?') usage && exit 0 ;;
		--ini-name) iniName="$1" && shift ;;
		--) break ;;
		*)
			{
				echo "error: unknown flag: $flag"
				usage
			} >&2
			exit 1
			;;
	esac
done

modules=
for module; do
	if [ -z "$module" ]; then
		continue
	fi
	if ! [ -f "$module" ] && ! [ -f "$module.so" ]; then
		echo >&2 "error: '$module' does not exist"
		echo >&2
		usage >&2
		exit 1
	fi
	modules="$modules $module"
done

if [ -z "$modules" ]; then
	usage >&2
	exit 1
fi

pm='unknown'
if [ -e /lib/apk/db/installed ]; then
	pm='apk'
fi

apkDel=
if [ "$pm" = 'apk' ]; then
	if \
		[ -n "$PHPIZE_DEPS" ] \
		&& ! apk info --installed .phpize-deps > /dev/null \
		&& ! apk info --installed .phpize-deps-configure > /dev/null \
	; then
		apk add --no-cache --virtual '.docker-php-ext-enable-deps' binutils
		apkDel='.docker-php-ext-enable-deps'
	fi
fi

for module in $modules; do
	moduleFile="$module"
	if [ -f "$module.so" ] && ! [ -f "$module" ]; then
		moduleFile="$module.so"
	fi
	if readelf --wide --syms "$moduleFile" | grep -q ' zend_extension_entry$'; then
		# https://wiki.php.net/internals/extensions#loading_zend_extensions
		line="zend_extension=$module"
	else
		line="extension=$module"
	fi

	ext="$(basename "$module")"
	ext="${ext%.*}"
	if php -d 'display_errors=stderr' -r 'exit(extension_loaded("'"$ext"'") ? 0 : 1);'; then
		# this isn't perfect, but it's better than nothing
		# (for example, 'opcache.so' presents inside PHP as 'Zend OPcache', not 'opcache')
		echo >&2
		echo >&2 "warning: $ext ($module) is already loaded!"
		echo >&2
		continue
	fi

	case "$iniName" in
		/*)
			# allow an absolute path
			ini="$iniName"
			;;
		*)
			ini="$PHP_INI_DIR/conf.d/${iniName:-"docker-php-ext-$ext.ini"}"
			;;
	esac
	if ! grep -qFx -e "$line" -e "$line.so" "$ini" 2>/dev/null; then
		echo "$line" >> "$ini"
	fi
done

if [ "$pm" = 'apk' ] && [ -n "$apkDel" ]; then
	apk del --no-network $apkDel
fi