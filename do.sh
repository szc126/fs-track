#!/usr/bin/env bash

set -u

verb="${1}"
user_id="${2}"
last_dl_date=$(cat "${user_id}/date.txt")
last_dl_date_epoch=$(date --date="${last_dl_date}" "+%s")

mkdir --parents "${user_id}"
wget "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes" --output-document="${user_id}/page-1.htm" --verbose

page_last=$(grep "fs-pagination__last" "${user_id}/page-1.htm" --context=1 | grep -P "(?<=page=)[0-9]+" --only-matching)

for page_i in $(seq 2 "${page_last?:}")
do
	wget "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes&page=${page_i}" --output-document="${user_id}/page-${page_i}.htm"
done

all_caught_up=""

for file in "${user_id}/page-"*".htm"
do
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

		# the fontstruction was renamed.
		# find the existing folder
		fsn_folder_existing=$(find -wholename "./${user_id}/${fsn_id} *" -type d)
		if [ "./${fsn_folder}" != "${fsn_folder_existing}" ] && [ "${fsn_folder_existing}" != "" ]
		then
			mv "${fsn_folder_existing}" "${fsn_folder}" --verbose --no-clobber
		fi

		case "${verb}" in
			"init")
				mkdir "${fsn_folder}"
				wget "https://fontstruct.com/api/1/fontstructions/${fsn_id}?fast=1&v=${fsn_v}&_cacheable_fragment=1" --output-document="${fsn_out_file}"
				;;
			"update")
				if [ "${fsn_modified_epoch}" -ge "${last_dl_date_epoch}" ]
				then
					mkdir --parents "${fsn_folder}"
					wget "https://fontstruct.com/api/1/fontstructions/${fsn_id}?fast=1&v=${fsn_v}&_cacheable_fragment=1" --output-document="${fsn_out_file}"
				else
					all_caught_up="true"
					break
				fi
				;;
		esac

		if [ "${all_caught_up}" == "true" ]
		then
			break
		fi

		#fsn_slug=$(jq ".slug" "${fsn_out_file}" -r)
		fsn_modified_seconds_n=$(jq ".modified" "${fsn_out_file}" -r | sed "s/://g")
		fsn_out_file_new="${fsn_folder}/${fsn_modified_seconds_n}.json"

		mv "${fsn_out_file}" "${fsn_out_file_new}" --verbose --no-clobber
	done
done

TZ="Europe/Berlin" LANG=C date "+%-d %B %Y" > "${user_id}/date.txt"
