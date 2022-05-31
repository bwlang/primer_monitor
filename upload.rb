#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment' # loads rails env, models, etc.

# aggregates results from the passed files and stores them in the configured database

@log = ActiveRecord::Base.logger = Logger.new($stderr)

def setup_db_connection
  db_config = YAML.safe_load(
    File.open(
      File.join(
        File.dirname(__FILE__), 'config', 'database.yml'
      )
    ), aliases: true
  )[ENV['DATABASE_ENV'] || 'production']
  ActiveRecord::Base.establish_connection(db_config)
end

def define_options
  Slop.parse(ARGV.map(&:strip)) do |o|
    o.string '--metadata_tsv', 'TSV file containing metadata information'
    o.string '--variants_tsv', 'TSV file containing variants information'
      o.string '--variants_tsv', 'Tsv file containing variants information'
    o.bool '--skip_data_import', 'Performs the data import steps', default: false
    o.bool '--skip_view_rebuild', 'Rebuilds materialized views', default: false

    # The available log levels are: :debug, :info, :warn, :error, and
    # :fatal, corresponding to the log level numbers from 0 up to 4
    # respectively. See rails docs.
    o.string '--verbose', 'Verbosity level of ActiveRecord logger', default: 'INFO'

    o.on '--help', '-h' do
      puts o
      exit
    end
  end
end

def parse_options
  begin
    slop_opts = define_options
  rescue Slop::MissingArgument => e
    @log.error "fatal: #{e}"
    exit(1)
  rescue Slop::UnknownOption => e
    @log.error "fatal: #{e}"
    exit(1)
  end
  slop_opts.to_hash
end

def import_metadata(metadata_file)
  return unless metadata_file

  fasta_records = FastaRecord.parse(metadata_file)
  result = FastaRecord.import(fasta_records, validate: false)
  result.failed_instances.each { |rec| @log.error("Failed to insert #{rec}") }
  @log.debug("Loaded #{result.ids.size}/#{fasta_records.size} new fasta records")
end

def import_variants(variants_file)
  return unless variants_file

  variant_records = VariantSite.parse(variants_file)
  fasta_ids = variant_records.map(&:fasta_record_id).uniq
  #VariantSite.where(fasta_record_id: fasta_ids).delete_all
  VariantSite.import(variant_records, validate: false)
end

def create_new_notifications!
  new_proposed_notifications = ProposedNotification.new_proposed_notifications()
  return if new_proposed_notifications.empty?

  ProposedNotification.import(new_proposed_notifications, validate: false)
end

def main
  opts = parse_options
  @log.level = Logger.const_get(opts[:verbose])

  setup_db_connection
  ActiveRecord::Base.transaction do
    unless opts[:skip_data_import]
      import_metadata(opts[:metadata_tsv])
      import_variants(opts[:variants_tsv])
    end
    unless opts[:skip_view_rebuild]
      %w[variant_overlaps counts time_counts oligo_variant_overlaps
         identify_primers_for_notifications initial_score].each do |view|
        ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW #{view}")
        Logger.info("refreshing #{view}")
      end
      create_new_notifications!
      # cannot send notifications here since this may be running on a cluster node.
    end
  end
end
main if $PROGRAM_NAME.end_with?('upload.rb')
