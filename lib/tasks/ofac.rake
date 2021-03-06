require 'ofac/ofac_xml_loader'

namespace :ofac do
  desc "Loads the current file from http://www.treasury.gov/resource-center/sanctions/SDN-List/Pages/default.aspx"
  task :update_data => :environment do
    OfacSdnIndividualLoader.new.load_current_sdn_file

    OfacXmlLoader.new.load_current_sdn_file
  end

end