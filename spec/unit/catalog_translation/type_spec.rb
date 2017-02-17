require 'spec_helper'

describe "PuppetX::CatalogTranslation::Type" do
  before :each do
    PuppetX::CatalogTranslation::Type.clear
  end

  describe "#translate!" do
    context "when dealing with unhandled resource attributes" do
      let(:translator) { PuppetX::CatalogTranslation::Type.translation_for(:service) }
      let(:resource) { Puppet::Type.type(:service).new(:name => 'spec', :hasrestart => true, :provider => 'systemd' ) }

      it "emits a warning" do
        Puppet.expects(:warning).with(regexp_matches /cannot translate.*hasrestart/)
        translator.translate!(resource)
      end

      it "returns the original type in optimistic mode" do
        PuppetX::CatalogTranslation.stubs(:mode).returns(:optimistic)
        type, _ = translator.translate!(resource)
        expect(type).to equal(:service)
      end

      it "returns an exec resource in conservative mode" do
        PuppetX::CatalogTranslation.stubs(:mode).returns(:conservative)
        type, _ = translator.translate!(resource)
        expect(type).to equal(:exec)
      end
    end

    it "emits no warning for ignored resource attributes" do
      translator = PuppetX::CatalogTranslation::Type.translation_for(:service)
      resource = Puppet::Type.type(:service).new(:name => 'spec', :loglevel => :notice, :provider => 'systemd' )
      Puppet.expects(:warning).never
      translator.translate!(resource)
    end

    it "emits no warning for catch-all translators" do
      PuppetX::CatalogTranslation::Type.new :notify do
        catch_all
      end
      resource = Puppet::Type.type(:notify).new(:name => 'spec', :message => 'this should not carp', :withpath => true)
      translator = PuppetX::CatalogTranslation::Type.translation_for(:notify)
      Puppet.expects(:warning).never
      translator.translate!(resource)
    end
  end

  describe "::translation_for" do
    it "loads the default translator if that has not yet happened" do
      PuppetX::CatalogTranslation::Type.expects(:load_translator).with(:default_translation)
      PuppetX::CatalogTranslation::Type.expects(:load_translator).with(:file)
      PuppetX::CatalogTranslation::Type.translation_for(:file)
    end

    it "returns the default translator if there is no specific one" do
      default_translation = PuppetX::CatalogTranslation::Type.translation_for(:default_translation)
      cron_translation = PuppetX::CatalogTranslation::Type.translation_for(:cron)
      expect(cron_translation).to be default_translation
    end
               
  end

  describe "#unsupported" do
    let(:translator) { PuppetX::CatalogTranslation::Type.translation_for(:service) }

    it "sends warnings to the logging subsystem" do
      Puppet.expects(:warning)
      translator.send :unsupported, "This is a warning"
    end

    it "sends errors to the logging subsystem" do
      Puppet.expects(:err)
      translator.send :unsupported, "This is an error", :err
    end

    it "does not accept invalid message levels" do
      expect {translator.send :unsupported, "This is an error", :initialize}.to raise_error(/initialize/)
    end

    it "warns about conservative mode only once" do
      PuppetX::CatalogTranslation.stubs(:mode).returns(:conservative)
      Puppet.expects(:warning).with(regexp_matches(/exec puppet resource/))
      Puppet.stubs(:warning).with(regexp_matches(/pattern|hasrestart/))

      # TODO: add a method to access @resource so that we
      # don't have to rely on translate! for this test
      # (currently it will fail otherwise because @resource is nil)
      resource = Puppet::Type.type(:service).new(:name => 'spec', :hasrestart => true, :provider => 'systemd', :pattern => 'x')
      translator.translate!(resource)
    end

    it "marks the translation as unclean" do
      PuppetX::CatalogTranslation.stubs(:mode).returns(:conservative)
      translator.expects(:mark_as_unclean)

      # TODO: add a method to access @resource so that we
      # don't have to rely on translate! for this test
      # (currently it will fail otherwise because @resource is nil)
      resource = Puppet::Type.type(:service).new(:name => 'spec', :hasrestart => true, :provider => 'systemd')
      translator.translate!(resource)
    end
  end
end
