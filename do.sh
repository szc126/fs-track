#!/usr/bin/env bash

set -u

verb="${1}"
user_id="${2}"
last_dl_date=$(cat "${user_id}/date.txt")
last_dl_date_epoch=$(date --date="${last_dl_date}" "+%s")

mkdir --verbose --parents "${user_id}"
wget --no-verbose "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes" --output-document="${user_id}/page-1.htm"

page_last=$(grep "fs-pagination__last" "${user_id}/page-1.htm" --context=1 | grep -P "(?<=page=)[0-9]+" --only-matching)

for page_i in $(seq 2 "${page_last?:}")
do
	wget --no-verbose "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes&page=${page_i}" --output-document="${user_id}/page-${page_i}.htm"
done

for file in "${user_id}/page-"*".htm"
do
	echo "${file}"

	#for fsn_render_url in $(grep -E "[^\"]+renderer[^\"]+" "${file}" --only-matching)
	grep -P "renderer" "${file}" --after-context=3 --group-separator=$'\035' | while read -r -d $'\035' fsn_datax
	do
		fsn_render_url=$(echo "${fsn_datax}" | grep -E "[^\"]+renderer[^\"]+" --only-matching)
		fsn_slug=$(echo "${fsn_datax}" | grep -P "[^/]+(?=#comments)" --only-matching)
		fsn_modified=$(echo "${fsn_datax}" | grep -P "(?<=Last edited: <b>)([^<>]+)" --only-matching | sed -E "s/([0-9])(st|nd|rd|th)|,/\1/g")
		fsn_modified_n=$(date --date="${fsn_modified}" "+%F")
		fsn_modified_epoch=$(date --date="${fsn_modified}" "+%s")

		fsn_id=$(echo "${fsn_render_url}" | grep -P "(?<=id=)[0-9]+" --only-matching)
		fsn_v=$(echo "${fsn_render_url}" | grep -P "(?<=v=)[0-9a-z]+" --only-matching) # what is this anyway?
		fsn_folder="${user_id}/${fsn_id} ${fsn_slug}"
		fsn_out_file="${fsn_folder}/${fsn_modified_n}.json"

		echo
		echo "${fsn_slug}"
		echo "${fsn_modified}"

		# the fontstruction was renamed.
		# find the existing folder
		fsn_folder_existing=$(find -wholename "./${user_id}/${fsn_id} *" -type d)
		if [ "./${fsn_folder}" != "${fsn_folder_existing}" ] && [ "${fsn_folder_existing}" != "" ]
		then
			mv --verbose "${fsn_folder_existing}" "${fsn_folder}" --no-clobber
		fi

		case "${verb}" in
			"init")
				mkdir --verbose "${fsn_folder}"
				wget --no-verbose "https://fontstruct.com/api/1/fontstructions/${fsn_id}?fast=1&v=${fsn_v}&_cacheable_fragment=1" --output-document="${fsn_out_file}"
				;;
			"update")
				if [ "${fsn_modified_epoch}" -ge "${last_dl_date_epoch}" ]
				then
					mkdir --verbose --parents "${fsn_folder}"
					wget --no-verbose "https://fontstruct.com/api/1/fontstructions/${fsn_id}?fast=1&v=${fsn_v}&_cacheable_fragment=1" --output-document="${fsn_out_file}"
				else
					echo "All caught up."
					break
				fi
				;;
		esac

		#fsn_slug=$(jq ".slug" "${fsn_out_file}" -r)
		fsn_modified_seconds_n=$(jq ".modified" "${fsn_out_file}" -r | sed "s/://g")
		fsn_out_file_new="${fsn_folder}/${fsn_modified_seconds_n}.json"

		# `--no-clobber` is unnecessary
		# the timestamp will not collide of course
		# if redownloading a file, it will just exit and leave behind a duplicate
		mv --verbose "${fsn_out_file}" "${fsn_out_file_new}"
	done
done

TZ="Europe/Berlin" LANG=C date "+%-d %B %Y" > "${user_id}/date.txt"
