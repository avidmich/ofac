require 'test_helper'

class OfacTest < Test::Unit::TestCase

  context '' do
    setup do
      setup_ofac_sdn_table
      OfacSdnLoader.load_current_sdn_file #this method is mocked to load test files instead of the live files from the web.
    end

    should "give a score of 0 if no name is given" do
      assert_equal 0, Ofac.new({:address => '123 somewhere'}).score
      assert_equal 0, Ofac.new({:name => ''}).score
      assert_equal 0, Ofac.new({:name => ' '}).score
      assert_equal 0, Ofac.new({:name => nil}).score
      assert_equal 0, Ofac.new({:name => {:first_name => '',:last_name => ' '}}).score
      assert_equal 0, Ofac.new({:name => {:first_name => '',:last_name => '  '}}).score
      assert_equal 0, Ofac.new({:name => 'P T'}).score
    end

    should "give a score of 0 if there is no name match" do
      assert_equal 0, Ofac.new({:name => 'Kevin T P'}).score
    end

    should "give a score of 0 if there is no name match but there is an address and city match" do
      assert_equal 0, Ofac.new({:name => 'Kevin', :address => '123 somewhere ln', :city => 'Clearwater'}).score
    end

    should "give a score of 60 if there is a name match and deduct scores for non matches on address and city" do
      assert_equal 60, Ofac.new({:name => 'Oscar Hernandez'}).score
      assert_equal 60, Ofac.new({:name => {:first_name => 'Oscar', :last_name => 'Hernandez'}}).score
    end

    should "give a score of 30 if there is only a partial match" do
      assert_equal 30, Ofac.new({:name => 'Oscar de la Hernandez'}).score
      assert_equal 30, Ofac.new({:name => {:first_name => 'Oscar', :last_name => 'de la Hernandez'}}).score
    end

    should "handle first or last name not given" do
      assert_equal 60, Ofac.new({:name => {:first_name => 'Oscar', :last_name => ''}}).score
      assert_equal 60, Ofac.new({:name => {:first_name => 'Oscar', :last_name => nil}}).score
      assert_equal 60, Ofac.new({:name => {:first_name => nil, :last_name => 'Oscar'}}).score
      assert_equal 60, Ofac.new({:name => {:first_name => 'Oscar'}}).score
      assert_equal 60, Ofac.new({:name => {:first_name => '', :last_name => 'Oscar'}}).score
      assert_equal 60, Ofac.new({:name => {:last_name => 'Oscar'}}).score
    end

    should "deduct scores for non matches on address and city if data is in the database" do
      #if there is data for address or city in the database, and that info is passed in, then 10%
      #of the weight will be deducted if there is not match or sounds like match

      #only name matches
      assert_equal 56, Ofac.new({:name => 'Oscar Hernandez', :city => 'no match', :address => 'no match'}).score
      #only name matches
      assert_equal 56, Ofac.new({:name => 'Oscar Hernandez', :city => 'Las Vegas', :address => 'no match'}).score
      #name and city match
      assert_equal 89, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => 'no match'}).score
      #city is a partial match - Clearwater matches, but not Bay
      #score = 60 for name + 15 for Clearwater - (15 * .1) for Bay = 73.5
      assert_equal 74, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater Bay'}).score
    end

    should "not deduct from score if no data for city or address is in the database" do
      assert_equal 60, Ofac.new({:name => 'Luis Lopez', :city => 'no match', :address => 'no match'}).score
    end

    should "give a score of 60 if there is a name match on alternate identity name" do
      assert_equal 60, Ofac.new({:name => 'Alternate Name'}).score
    end

    should "give a partial score if there is a partial name match" do
      assert_equal 40, Ofac.new({:name => 'Oscar middlename Hernandez'}).score
      assert_equal 30, Ofac.new({:name => 'Oscar WrongLastName'}).score
      assert_equal 70, Ofac.new({:name => 'Oscar middlename Hernandez',:city => 'Clearwater'}).score
    end

    should "give a score of 90 if there is a name and city match" do
      assert_equal 90, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater'}).score
    end

    should "give a score of 100 if there is a name and city and address match" do
      assert_equal 100, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => '123 somewhere ln'}).score
    end

    should "give partial scores for sounds like matches" do

      #32456 summer lane sounds like 32456 Somewhere ln so is adds 75% of the address weight to the score, or 8.
      assert_equal 98, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => '32456 summer lane'}).score

      #summer sounds like somewhere, and all numbers sound alike, so 2 of the 3 address elements match by sound.
      #Each element is worth 10\3 or 3.33.  Exact matches add 2.33 each, and the sounds like adds 2.33 * .75 or 2.5
      #because sounds like matches only add 75% of it's weight.
      #2.5 + 2.5 = 5
      assert_equal 95, Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => '12358 summer blvd'}).score


      #Louis sounds like Luis, and Lopez is an exact match:
      #:name has a weight of 60, so each element is worth 30.  A sounds like match is worth 30 * .75
      assert_equal 53, Ofac.new({:name => 'Louis Lopez', :city => 'Las Vegas', :address => 'no match'}).score
    end

    should "return an array of possible hits" do
      #it should matter which order you call score or possible hits.
      sdn = Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => '123 somewhere ln'})
      assert sdn.score > 0
      assert !sdn.possible_hits.empty?

      sdn = Ofac.new({:name => 'Oscar Hernandez', :city => 'Clearwater', :address => '123 somewhere ln'})
      assert !sdn.possible_hits.empty?
      assert sdn.score > 0
    end
  end
end
