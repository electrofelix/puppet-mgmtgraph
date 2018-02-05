PuppetX::CatalogTranslation::Type.new :service do
  emit :svc

  spawn :name do
    @resource[:name]
  end

  rename :ensure, :state do |value|
    case value
    when :running, true, :true
      :running
    else
      :stopped
    end
  end

  rename :enable, :startup do |value|
    if value == true || value == :true
      :enabled
    else
      :disabled
    end
  end

  ignore :hasstatus

  ignore :provider do |value|
    if value != :systemd
      translation_failure "uses the #{value} provider, while mgmt will use systemd only."
    end
  end

  ignore :pattern do |value|
    if value != @resource[:name]
      translation_failure "uses the process name pattern '#{value}', which mgmt does not support."
    end
  end
end
