# frozen_string_literal: true

module ConfigHelpers
  DEFAULTS = {
    indices_directory: 'tmp/indices',
    clusters: {
      default: {
        client: { url: ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200') },
        index_prefix: 'esse_test',
        index_settings: {
          number_of_shards: 1,
          number_of_replicas: 0,
        },
      },
    },
  }.freeze

  def reset_config!
    Esse::Index.cluster_id = nil
    Esse.instance_variable_set(:@config, nil)
  end

  def with_config(opts = {})
    settings = DEFAULTS.dup.merge(opts)
    Esse.config.load(settings)

    yield Esse.config

    reset_config!
  end

  def stub_cluster_info(distribution: 'elasticsearch', version: '7.11.0')
    Esse.config.cluster_ids.each do |id|
      Esse.config.cluster(id).instance_variable_set(:@info, {
        distribution: distribution,
        version: version,
      })
    end
  end

  def with_cluster_config(id: :default, **opts)
    with_config { |c| c.cluster(id).assign(opts) }
  end

  def clear_active_record_hooks
    Thread.current[Esse::ActiveRecord::Hooks::STORE_STATE_KEY] = nil
  end
end
