# frozen_string_literal: true

require 'bio'
require 'optparse'
require 'uri'
require 'net/http'

module TP_Bio
      # Use EMBOSS' API to calculate ORFs of a given sequence, obtain possible protein sequences, and analyze
      # the obtained proteins.
      # API documentation obtained from https://www.ebi.ac.uk/Tools/common/tools/help/index.html
      class Ex5
        DEFAULT_GENBANK_FILE = File.join __dir__, 'NM_001317184.gbk'

        def get_sequence(args)
          if args[:in]
            Bio::FlatFile.new(Bio::FastaFormat, args[:in]).entries.first
          elsif args[:sequence]
            Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(args[:sequence])).entries.first
          else
            # Default to reading ex 1 GenBank file and returning sequence
            Bio::FlatFile.new(Bio::GenBank, File.open(DEFAULT_GENBANK_FILE, 'r'))
                         .map(&:to_biosequence)
                         .first
          end
        end

        # GETs a given result URL until response is 200 OK, waiting the given number of seconds up to a given
        # number of max attempts. Returns response body as-is, ie. a plain string.
        def get_emboss_result(result_url, wait_time, max_attempts)
          done = false
          attempts = 0
          until done
            url = URI(result_url)
            https = Net::HTTP.new(url.host, url.port)
            https.use_ssl = true
            request = Net::HTTP::Get.new(url)
            # request['Accept'] = 'application/json'
            response = https.request(request)
            done = response.code == '200'

            return response.read_body if done

            attempts += 1
            if attempts >= max_attempts
              puts "Not done after #{max_attempts} attempts, aborting"
              exit 1
            end
            puts "Job not complete yet, sleeping #{wait_time}s..."
            sleep wait_time
          end
        end

        # Use EMBOSS sixpack for calculating ORFs
        def emboss_orfs(sequence)
          url = URI('https://www.ebi.ac.uk/Tools/services/rest/emboss_sixpack/run')
          https = Net::HTTP.new(url.host, url.port)
          https.use_ssl = true
          request = Net::HTTP::Post.new(url)
          payload = {
            email: 'jlipumafinnemore@itba.edu.ar',
            condontable: 0, # Default codon table,
            reverse: false, # Don't reverse and compliment sequence
            sequence: sequence.to_fasta
          }
          request.set_form_data(payload)
          request['Accept'] = 'text/plain'
          response = https.request(request)
          job_id = response.read_body

          orfs = get_emboss_result("https://www.ebi.ac.uk/Tools/services/rest/emboss_sixpack/result/#{job_id}/result", 10, 10)
          Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(orfs)).entries
        end

        def emboss_pepinfo(sequence, out_dir)
          url = URI('https://www.ebi.ac.uk/Tools/services/rest/emboss_pepinfo/run')
          https = Net::HTTP.new(url.host, url.port)
          https.use_ssl = true
          request = Net::HTTP::Post.new(url)
          payload = {
              email: 'jlipumafinnemore@itba.edu.ar',
              sequence: sequence.to_fasta
          }
          request.set_form_data(payload)
          request['Accept'] = 'text/plain'
          response = https.request(request)
          job_id = response.read_body

          histogram = get_emboss_result("https://www.ebi.ac.uk/Tools/services/rest/emboss_pepinfo/result/#{job_id}/histograms", 10, 10)
          File.binwrite(File.join(out_dir, 'histogram.png'), histogram)
          histogram = get_emboss_result("https://www.ebi.ac.uk/Tools/services/rest/emboss_pepinfo/result/#{job_id}/histograms_table", 10, 10)
          File.write(File.join(out_dir, 'histogram.txt'), histogram)
        end

        def run
          args = Options.new.parse
          sequence = get_sequence(args)

          puts 'Using EMBOSS to obtain sequence ORFs...'
          orfs = emboss_orfs sequence
          # Use the longest sequence as main reading frame
          target_sequence = orfs.max_by(&:length).to_biosequence
          puts "This is the longest translated ORF, will use this for the next step:\n#{target_sequence.to_fasta}"

          # Get protein info
          puts 'Obtaining histogram of physico-chemical properties for target ORF...'
          emboss_pepinfo(target_sequence, args[:out])
          puts "Wrote histogram files in #{File.absolute_path args[:out]}"
        end
      end

      class Options

        def parse
          args = { in: nil, out: '.', sequence: nil }

          OptionParser.new do |parser|
            parser.banner = "Usage: ruby #{File.expand_path 'main.rb', __dir__} [options]"

            parser.on('-i IN', '--in IN', 'Input nucleotide sequence FASTA file. If neither -i nor -s are provided, defaults to reading sequence from ex1 GenBank file.') do |x|
              args[:in] = x
            end
            parser.on('-o OUT', '--out OUT', 'Output directory. Defaults to cwd.') do |x|
              args[:out] = x
            end
            parser.on('-s SEQUENCE', '--sequence SEQUENCE', 'Nucleotide sequence in FASTA format. If neither -i nor -s are provided, defaults to reading sequence from ex1 GenBank file.') do |x|
              args[:sequence] = x
            end
          end.parse!

          unless File.directory? args[:out]
            puts "#{args[:out]} is not a directory"
            exit 1
          end

          # Convert in/out to files
          args[:in] = File.open(args[:in], 'r') unless args[:in].nil?

          args
        end
      end

      class Utils
    # Define "static" methods
    class << self

      # Extract UID from a BLAST report hit. This ID can be used in #ncbi_protein_lookup
      def extract_hit_id(hit)
        result = hit.accession
        unless result.index(':').nil? # : in accession means this isn't really an accession (eg. our blast_raw.txt)
          # ID is enclosed in [] at the beginning of the definition, extract.
          # The weird &.[] is a null-safe [0], see https://stackoverflow.com/questions/34794697/using-with-the-safe-navigation-operator-in-ruby
          result = hit.definition.scan(/^\[(.+)\]/)&.[](0)&.[](0)
        end
        result
      end

      # Look up proteins in NCBI by ID and return them as FASTA
      def ncbi_protein_lookup(ids)
        results = Bio::NCBI::REST::EFetch.protein(ids, 'fasta')
        parsed_results = Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(results))
        parsed_results.entries
      end
    end
  end

      Ex5.new.run if __FILE__ == $PROGRAM_NAME
end
