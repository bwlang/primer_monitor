nextflow.enable.dsl = 2

primer_names = params.primer_names
primer_names = file(primer_names).toAbsolutePath()

params.pct_cutoff =
pct_cutoff = params.pct_cutoff

params.score_cutoff =
score_cutoff = params.score_cutoff

params.primer_monitor_path =
primer_monitor_path = params.primer_monitor_path

params.organism_dirname =
organism_dirname = params.organism_dirname

params.override_path =
override_path = params.override_path
override_path = file(override_path).toAbsolutePath()

process recompute_affected_primers {
    cpus 8
    errorStrategy 'retry'
    maxRetries 2
    conda "libiconv psycopg2 bedtools coreutils 'postgresql>=15' gawk"
    input:
        file primer_names_file
    output:
        file 'primers_done.txt'
    shell:
    '''
    # recompute the primer data for igvjs visualization
    !{primer_monitor_path}/lib/visualization/recompute_affected_primers.sh -o !{override_path} -p !{primer_names_file} !{primer_monitor_path} !{organism_dirname} \
    !{pct_cutoff} !{score_cutoff} !{task.cpus};

    cp !{primer_names_file} primers_done.txt
    '''
}

process update_db {
    cpus 1
    errorStrategy 'retry'
    maxRetries 2
    conda "'postgresql>=15'"
    input:
        file completed_primers
    shell:
    '''

    source "!{primer_monitor_path}/.env"

    while read -f primer_set; do
        psql -h "$DB_HOST" -d "$DB_NAME" -U "$DB_USER_RO" -v "primer_set=$primer_set" <<< "UPDATE primer_sets SET status='complete' WHERE name=:'primer_set';";
    done < !{completed_primers}
    '''
}


workflow {
    recompute_affected_primers(params.primer_names)
    update_db(recompute_affected_primers.out)
}
