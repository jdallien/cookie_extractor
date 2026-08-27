require_relative "spec_helper"

describe CookieExtractor::SecretService do
  let(:bus) { double("bus") }
  let(:secrets_service) { double("secrets_service") }
  let(:secrets_object) { double("secrets_object") }
  let(:service) { double("service") }
  let(:prompt_object) { double("prompt_object") }
  let(:prompt_interface) { double("prompt_interface") }

  before do
    allow(DBus).to receive(:session_bus).and_return(bus)
    allow(bus).to receive(:service).with(described_class::SECRETS_SERVICE).and_return(secrets_service)
    allow(secrets_service).to receive(:object).with(described_class::SECRETS_PATH).and_return(secrets_object)
    allow(secrets_object).to receive(:[]).with(described_class::SERVICE_INTERFACE).and_return(service)
  end

  describe "#secrets" do
    let(:attributes) { { "application" => "chrome" } }
    let(:session_path) { "/org/freedesktop/secrets/session/121" }
    let(:item) { "/org/freedesktop/secrets/collection/kdewallet/0" }
    let(:prompt_path) { ["/org/freedesktop/secrets/prompt/p3"] }
    let(:secret) { { item => [session_path, [], [116, 101, 115, 116], "text/plain"] } }

    it "opens session and returns secrets for unlocked items" do
      allow(service).to receive(:OpenSession).with("plain", []).and_return([[], session_path])
      allow(service).to receive(:SearchItems).with(attributes).and_return([[item], []])
      allow(service).to receive(:GetSecrets).with([item], session_path).and_return([secret])

      expect(described_class.new.secrets(attributes)).to eq(["test"])
    end

    it "returns empty array when no unlocked items" do
      allow(service).to receive(:OpenSession).with("plain", []).and_return([[], session_path])
      allow(service).to receive(:SearchItems).with(attributes).and_return([[], []])
      expect(service).not_to receive(:GetSecrets)

      expect(described_class.new.secrets(attributes)).to eq([])
    end

    it "unlocks locked secrets" do
      allow(service).to receive(:OpenSession).with("plain", []).and_return([[], session_path])
      allow(service).to receive(:SearchItems).with(attributes).and_return([[], [item]])
      allow(service).to receive(:Unlock).with([item]).and_return([[], prompt_path])

      allow(secrets_service).to receive(:object).with(prompt_path).and_return(prompt_object)
      allow(prompt_object).to receive(:[]).with(described_class::PROMPT_INTERFACE).and_return(prompt_interface)
      allow(prompt_interface).to receive(:Prompt).with("").and_return(nil)

      main_double = double("main")
      allow(DBus::Main).to receive(:new).and_return(main_double)
      allow(main_double).to receive(:<<).with(bus)
      allow(main_double).to receive(:quit)
      allow(main_double).to receive(:run)

      # user cancels
      cancel = true
      allow(prompt_interface).to receive(:on_signal).with("Completed") do |&block|
        block.call(cancel, cancel ? [] : [item])
      end

      allow(service).to receive(:GetSecrets).with([item], session_path).and_return([secret])

      expect(described_class.new.secrets(attributes)).to eq([])

      cancel = false
      expect(described_class.new.secrets(attributes)).to eq(["test"])
    end
  end

end
