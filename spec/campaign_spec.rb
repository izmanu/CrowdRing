require File.dirname(__FILE__) + '/spec_helper'

describe Crowdring::Campaign do
  let(:campaign) { create(:campaign) }
  it { should validate_presence_of :goal }
  it { should have_many :rings }
  it { should have_many :asks }
  it { should have_many :ivrs }
  it { should have_many :aggregate_campaigns }
  it { should have_many :voice_numbers }
  it { should have_one :sms_number }
  def app
    Crowdring::Server
  end


  describe 'campaign creation' do
    before(:each) do
      DataMapper.auto_migrate!
      @number1 = {phone_number: '+18001111111', description: 'num1'}
      @number2 = '+18002222222'
      @number3 = '+18003333333'
      @c = Crowdring::Campaign.create(title: 'test')
    end

    it 'should create a campaign with a voice number and a sms number' do
      @campaign = Crowdring::Campaign.create(title: 'test2', voice_numbers: [@number1], sms_number: @number2)

      @campaign.save.should be_true    
      @campaign.voice_numbers.first.should eq(Crowdring::AssignedVoiceNumber.first)
      @campaign.sms_number.should eq(Crowdring::AssignedSMSNumber.first)
    end
   
    it 'should remove the assigned numbers on campaign destruction' do
      @c.voice_numbers.new(@number1)
      @c.sms_number = @number2
      @c.save

      @c.destroy.should be_true
      Crowdring::AssignedCampaignVoiceNumber.all.should be_empty
      Crowdring::AssignedSMSNumber.all.should be_empty
    end

    it 'should not allow assignment of an invalid phone number' do
      @c.voice_numbers.new({phone_number:'badger, badger', description: 'nonsense'})
      @c.save.should be_false
    end

    it 'should not allow assigning the same number to multiple campaigns' do
      c1 = Crowdring::Campaign.create(title: 'test1')
      c1.voice_numbers.new(@number1)
      c1.save

      c2 = Crowdring::Campaign.create(title: 'test2')
      c2.voice_numbers.new(@number1)
      
      c2.save.should be_false   
    end

    it 'should create a default offline ask upon campaign creation' do
      c1 = Crowdring::Campaign.create(title: 'test1', voice_numbers: [{phone_number: '18001111111', description: 'foo'}])

      c1.saved?.should be_true
      c1.asks.first.is_a?(Crowdring::OfflineAsk).should be_true
    end

    it 'should not allow creation of 2 campaigns with the same name and provide a useful error' do
      c1 = Crowdring::Campaign.create(title: 'test', voice_numbers: [{phone_number: '18001111111', description: 'foo'}])
      c2 = Crowdring::Campaign.new(title: 'test', voice_numbers: [{phone_number: '18001111112', description: 'bar'}])

      c1.save.should be_true
      c2.save.should be_false
      c2.all_errors.map(&:full_messages).join('|').should match(/title/i)
    end
  end

  describe 'campaign and ringer' do
    before(:each) do
      DataMapper.auto_migrate!
      @number1 = '+18001111111'
      @number2 = '+18002222222'
      @number3 = '+18003333333'
      @number4 = '+18004444444'
      @number5 = '+18005555555'
      @c = Crowdring::Campaign.create(title: 'test', voice_numbers: [{phone_number: @number2, description: 'num1'}], sms_number: @number3)
    end

    it 'should have many ringers' do
      r1 = Crowdring::Ringer.create(phone_number: @number1)
      r2 = Crowdring::Ringer.create(phone_number: @number2)
      @c.rings.create(ringer: r1)
      @c.rings.create(ringer: r2)

      @c.ringers.should include(Crowdring::Ringer.first(phone_number: @number1))
      @c.ringers.should include(Crowdring::Ringer.first(phone_number: @number2))
    end

    it 'should track the original date a ringer supported a campaign' do
      r = Crowdring::Ringer.create(phone_number: @number2)
      @c.voice_numbers.first.ring(r)

      @c.rings.first.created_at.to_date.should eq(Date.today)
    end

    it 'should track all of the times a ringer rings a campaign' do
      r = Crowdring::Ringer.create(phone_number: @number2)
      @c.voice_numbers.first.ring(r)

      @c.rings.count.should eq(1)
    end

    it 'should remove rings when a campaign is destroyed' do
      r = Crowdring::Ringer.create(phone_number: @number2)
      @c.voice_numbers.first.ring(r)
      @c.destroy

      Crowdring::Ring.all.should be_empty
      Crowdring::Ringer.all.count.should eq(1)
    end

    it 'should be able to provide the ringers of a certain assigned number' do
      @c.voice_numbers << {phone_number: @number3, description: 'num3'}
      @c.save
      r = Crowdring::Ringer.create(phone_number: @number4)
      r2 = Crowdring::Ringer.create(phone_number: @number5)
      @c.voice_numbers.first.ring(r)
      @c.voice_numbers.last.ring(r2)

      @c.ringers_from(@c.voice_numbers.first).should eq([r])
      @c.ringers_from(@c.voice_numbers.last).should eq([r2])
    end
  end

end
