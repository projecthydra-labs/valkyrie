# frozen_string_literal: true
module FedoraHelper
  def fedora_adapter_config(base_path:, schema: nil, fedora_version: 4)
    port = fedora_version == 4 ? 8988 : 8998
    opts = {
      base_path: base_path,
      connection: ::Ldp::Client.new("http://#{fedora_auth}localhost:#{port}/rest"),
      fedora_version: fedora_version
    }
    opts[:schema] = schema if schema
    opts
  end

  def fedora_auth
    "fedoraAdmin:fedoraAdmin@"
  end

  def wipe_fedora!(base_path:, fedora_version: 4)
    Valkyrie::Persistence::Fedora::MetadataAdapter.new(fedora_adapter_config(base_path: base_path, fedora_version: fedora_version)).persister.wipe!
  end
end

RSpec.configure do |config|
  config.before do
    wipe_fedora!(base_path: "test_fed", fedora_version: 4)
    wipe_fedora!(base_path: "test_fed", fedora_version: 5)
  end
  config.include FedoraHelper
end
