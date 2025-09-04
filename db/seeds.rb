  Faker::Config.locale = 'pt-BR'

  puts "Limpando o banco de dados..."
  Message.destroy_all
  Schedule.destroy_all
  Service.destroy_all
  User.destroy_all


  # --- 1. CRIANDO USUÁRIOS (CLIENTES E PROFISSIONAIS) ---

  puts "Criando 20 usuários (5 profissionais e 15 clientes)..."

  # Lista de cidades e endereços reais por estado para garantir geocoding
  CITIES_BY_STATE = {
    "SP" => [
      { city: "São Paulo", address: "Avenida Paulista, 1576", cep: "01310-200" },
      { city: "Campinas", address: "Rua Doutor Quirino, 1000", cep: "13015-081" },
      { city: "Guarulhos", address: "Rua Doutor João de Deus, 33", cep: "07020-090" }
    ],
    "RJ" => [
      { city: "Rio de Janeiro", address: "Rua do Catete, 110", cep: "22220-001" },
      { city: "Niterói", address: "Rua Visconde do Rio Branco, 250", cep: "24020-006" }
    ],
    "MG" => [
      { city: "Belo Horizonte", address: "Rua Pernambuco, 2030", cep: "30130-160" },
      { city: "Uberlândia", address: "Avenida João Naves de Ávila, 1331", cep: "38400-000" }
    ],
    "ES" => [
      { city: "Vitória", address: "Rua Sete de Setembro, 201", cep: "29015-000" },
      { city: "Vila Velha", address: "Rua Henrique Moscoso, 1320", cep: "29100-240" }
    ],
    "PR" => [
      { city: "Curitiba", address: "Rua XV de Novembro, 800", cep: "80020-300" },
      { city: "Londrina", address: "Avenida Higienópolis, 1600", cep: "86015-000" },
      { city: "Maringá", address: "Avenida Brasil, 2560", cep: "87013-000" }
    ],
    "SC" => [
      { city: "Florianópolis", address: "Rua Felipe Schmidt, 600", cep: "88010-000" },
      { city: "Joinville", address: "Rua Nove de Março, 200", cep: "89201-500" }
    ],
    "RS" => [
      { city: "Porto Alegre", address: "Rua dos Andradas, 1234", cep: "90020-007" },
      { city: "Caxias do Sul", address: "Rua Sinimbu, 200", cep: "95020-001" }
    ]
  }


  # Define as regiões-alvo a partir das chaves do hash
  REGIOES_ALVO = CITIES_BY_STATE.keys

  # Usuários específicos com dados reais para geocoding
  user_data = []

  5.times do
    random_state = REGIOES_ALVO.sample
    address_data = CITIES_BY_STATE[random_state].sample

    user_data << {
      name: Faker::Name.name,
      email: Faker::Internet.unique.email,
      address: address_data[:address],
      address_number: "",
      cep: address_data[:cep].gsub(/\D/, ''),
      city: address_data[:city],
      state: random_state,
      password: "password",
      role: :professional,
      profile_completed: true
    }
  end

  15.times do
    random_state = REGIOES_ALVO.sample
    address_data = CITIES_BY_STATE[random_state].sample

    user_data << {
      name: Faker::Name.name,
      email: Faker::Internet.unique.email,
      address: address_data[:address],
      address_number: "",
      cep: address_data[:cep].gsub(/\D/, ''),
      city: address_data[:city],
      state: random_state,
      password: "password",
      role: :client,
      profile_completed: true
    }
  end

  User.create!(user_data)
  puts "✅ Usuários criados com sucesso!"


  # --- 2. CRIANDO SERVIÇOS PROFISSIONAIS ---
  puts "Criando 50 serviços..."

  professional_users = User.where(role: :professional)

  CATEGORIES = ["Serviços Domésticos", "Reparos e Manutenção", "Saúde e Bem-Estar", "Aulas e Cursos", "Consultoria", "Eventos", "Serviços de Saúde e Estética", "Serviços Automotivos"]
  SUBCATEGORIES = {
    "Serviços Domésticos" => ["Limpeza", "Jardinagem", "Cozinhar"],
    "Reparos e Manutenção" => ["Elétrica", "Hidráulica", "Pintura", "Montagem de Móveis"],
    "Saúde e Bem-Estar" => ["Massagem", "Personal Trainer", "Fisioterapia"],
    "Aulas e Cursos" => ["Música", "Idiomas", "Artes Marciais"],
    "Consultoria" => ["Financeira", "Tecnológica", "Marketing"],
    "Eventos" => ["Fotografia", "Catering", "Decoração"],
    "Serviços de Saúde e Estética" => ["Dentista", "Cabeleireiro", "Barbeiro", "Manicure"],
    "Serviços Automotivos" => ["Mecânica", "Lavagem", "Funilaria", "Pintura"]
  }

  50.times do
    category = CATEGORIES.sample
    subcategory = SUBCATEGORIES[category].sample

    service_name = if category == "Serviços de Saúde e Estética"
        "#{subcategory} - #{Faker::Company.name}"
      elsif category == "Serviços Automotivos"
        "Oficina de #{subcategory} - #{Faker::Company.name}"
      else
        Faker::Job.unique.title
    end

    Service.create!(
      name: service_name,
      description: Faker::Lorem.paragraph(sentence_count: 2),
      categories: category,
      subcategories: subcategory,
      price_hour_cents: (Faker::Commerce.price(range: 40.0..200.0) * 100).to_i,
      average_hours: Faker::Number.between(from: 1, to: 10),
      user: professional_users.sample
    )
  end

  puts "✅ #{Service.count} serviços criados com sucesso!"


# --- 3. CRIANDO AGENDAMENTOS (SCHEDULES) ---
puts "Criando 30 agendamentos..."

client_users = User.where(role: :client)
services     = Service.all

# helper: retorna um slot livre [start_at, end_at] para o profissional (dono do service)
  def free_slot_for_provider(provider_id, duration_hours:, days_ahead: 15, open_hour: 9, close_hour: 18)
    dur = duration_hours.to_i
    raise ArgumentError, "duration_hours precisa ser >= 1" if dur < 1

    40.times do
      # escolhe um dia nas próximas N janelas
      date = Date.current + rand(0...days_ahead).days

      # última hora que ainda permite terminar antes de close_hour
      latest_start = [close_hour - dur, open_hour].max
      next if latest_start < open_hour

      hour     = rand(open_hour..latest_start)
      start_at = Time.zone.local(date.year, date.month, date.day, hour, 0, 0)
      end_at   = start_at + dur.hours

      # conflito: qualquer schedule do MESMO provider cuja janela se sobrepõe
      conflict = Schedule.joins(:service)
                        .where(services: { user_id: provider_id })
                        .where("start_at < ? AND end_at > ?", end_at, start_at)
                        .exists?

      return [start_at, end_at] unless conflict
    end

    nil
  end

  created  = 0
  attempts = 0

  while created < 30 && attempts < 200
    attempts += 1

    service = services.sample
    client  = client_users.sample
    dur     = (service.average_hours.presence || rand(1..3)).to_i

    slot = free_slot_for_provider(service.user_id, duration_hours: dur)
    next unless slot

    start_at, end_at = slot

    accepted_client       = [true, false].sample
    accepted_professional = [true, false].sample
    confirmed             = accepted_client && accepted_professional

    begin
      Schedule.create!(
        user:                   client,    # cliente
        service:                service,   # provider = service.user
        start_at:               start_at,
        end_at:                 end_at,
        accepted_client:        accepted_client,
        accepted_professional:  accepted_professional,
        confirmed:              confirmed
      )
      created += 1
    rescue ActiveRecord::RecordInvalid
      next
    end
  end

  puts "✅ #{created} agendamentos criados com sucesso!"

  # --- 4. CRIANDO MENSAGENS PARA OS AGENDAMENTOS ---
  puts "Criando 50 mensagens..."

  schedules = Schedule.all

  50.times do
    schedule = schedules.sample
    client_user = schedule.user
    professional_user = schedule.service.user

    user = [client_user, professional_user].sample

    Message.create!(
      user: user,
      schedule: schedule,
      content: Faker::Lorem.sentence
    )
  end

  puts "✅ #{Message.count} mensagens criadas com sucesso!"


  # --- 5. CRIANDO IMAGENS ---
  puts "Criando imagens para profissionais..."

  IMAGE_MAP = {
    "Serviços Domésticos" => "servico_servicos_domesticos.png",
    "Reparos e Manutenção" => "servico_reparo_manutencao.png",
    "Saúde e Bem-Estar" => "servico_saude.png",
    "Aulas e Cursos" => "servico_consultoria.png",
    "Consultoria" => "servico_consultoria.png",
    "Eventos" => "servico_eventos.png",
    "Serviços de Saúde e Estética" => "servico_saude.png",
    "Serviços Automotivos" => "servico_reparo_manutencao.png"
  }

  professional_users.each do |professional|
    service = professional.services.first
    next unless service

    image_name = IMAGE_MAP[service.categories]
    image_path = Rails.root.join('app/assets/images', image_name)

    if image_path.exist?
      professional.images.attach(
        io: File.open(image_path),
        filename: image_name,
        content_type: "image/png"
      )
    end
  end

  puts "✅ Imagens anexadas aos profissionais com sucesso!"


  puts "Seeds completas!"
