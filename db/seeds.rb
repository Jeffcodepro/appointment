# db/seeds.rb
Faker::Config.locale = 'pt-BR'

puts "Limpando o banco..."
Message.delete_all
Schedule.delete_all
Conversation.delete_all
Service.delete_all
User.delete_all


# ---------- Endereços reais (Sul e Sudeste) ----------
CITIES_BY_STATE = {
  # Sudeste
  "SP" => [
    { city: "São Paulo",       address: "Avenida Paulista, 1578",     cep: "01310-200" },
    { city: "Campinas",        address: "Rua Dr. Quirino, 1000",      cep: "13015-081" },
    { city: "Santos",          address: "Av. Ana Costa, 318",          cep: "11060-002" }
  ],
  "RJ" => [
    { city: "Rio de Janeiro",  address: "Rua do Catete, 110",          cep: "22220-000" },
    { city: "Niterói",         address: "Rua Visconde do Rio Branco, 251", cep: "24020-006" }
  ],
  "MG" => [
    { city: "Belo Horizonte",  address: "Av. Amazonas, 1830",          cep: "30180-001" },
    { city: "Uberlândia",      address: "Av. João Naves de Ávila, 1331", cep: "38400-902" }
  ],
  "ES" => [
    { city: "Vitória",         address: "Av. Jerônimo Monteiro, 1000", cep: "29010-002" },
    { city: "Vila Velha",      address: "Rua Henrique Moscoso, 1320",  cep: "29100-240" }
  ],

  # Sul
  "PR" => [
    { city: "Curitiba",        address: "Rua XV de Novembro, 800",     cep: "80020-310" },
    { city: "Londrina",        address: "Av. Higienópolis, 1600",      cep: "86015-010" }
  ],
  "SC" => [
    { city: "Florianópolis",   address: "Rua Felipe Schmidt, 600",     cep: "88010-001" },
    { city: "Joinville",       address: "Rua Nove de Março, 200",      cep: "89201-500" }
  ],
  "RS" => [
    { city: "Porto Alegre",    address: "Rua dos Andradas, 1234",      cep: "90020-007" },
    { city: "Caxias do Sul",   address: "Rua Sinimbu, 200",            cep: "95020-001" }
  ]
}.freeze
UF_SUL_SUDESTE = CITIES_BY_STATE.keys

# ---------- Categorias/Subcategorias ----------
CATEGORIES = [
  "Salão de beleza",
  "Fotografia",
  "Consultório odontológico",
  "Serviços domésticos",
  "Pequenos reparos em casa"
].freeze

SUBCATEGORIES = {
  "Salão de beleza" => [
    "Corte de cabelo", "Escova", "Coloração",
    "Manicure", "Pedicure", "Maquiagem", "Design de sobrancelhas"
  ],
  "Fotografia" => [
    "Ensaio externo", "Eventos", "Produtos",
    "Newborn", "Casamento", "Retrato corporativo"
  ],
  "Consultório odontológico" => [
    "Limpeza", "Clareamento dental", "Restauração",
    "Tratamento de canal", "Ortodontia", "Implante"
  ],
  "Serviços domésticos" => [
    "Faxina residencial", "Diarista", "Passadoria",
    "Organização", "Limpeza pós-obra"
  ],
  "Pequenos reparos em casa" => [
    "Eletricista", "Encanador", "Pintura",
    "Marido de aluguel", "Montagem de móveis", "Pequenos consertos"
  ]
}.freeze


# --- helpers de texto --- #
def pro_bio_for(category, city:)
  case category
  when "Salão de beleza"
    [
      "Profissional de beleza com mais de #{rand(3..12)} anos de experiência.",
      "Atendo em #{city} com foco em higiene, biossegurança e acabamento impecável.",
      "Trabalho com marcas profissionais e horários com agendamento."
    ].join(" ")
  when "Fotografia"
    [
      "Fotógraf@ em #{city}, apaixonad@ por registrar histórias reais.",
      "Atendimento humanizado do briefing à entrega, com direção de pose leve.",
      "Equipamentos full-frame e backup de arquivos."
    ].join(" ")
  when "Consultório odontológico"
    [
      "Cirurgiã(o)-dentista atuando em #{city}, atendimento acolhedor e pontual.",
      "Protocolos de esterilização e materiais de primeira linha.",
      "Planos de tratamento claros e acompanhamento pós-procedimento."
    ].join(" ")
  when "Serviços domésticos"
    [
      "Profissional de limpeza e organização em #{city}.",
      "Checklists personalizados por ambiente e produtos adequados a cada superfície.",
      "Compromisso com pontualidade e discrição."
    ].join(" ")
  when "Pequenos reparos em casa"
    [
      "Técnic@ de manutenção residencial em #{city}.",
      "Diagnóstico rápido, orçamento antes de iniciar e garantia do serviço.",
      "Atendimento de segunda a sábado, horário comercial."
    ].join(" ")
  else
    "Profissional atuante em #{city}, atendimento com agendamento e foco em qualidade."
  end
end

def service_description_for(category, sub)
  case category
  when "Salão de beleza"
    {
      "Corte de cabelo" => "Consulta de visagismo, lavagem, corte técnico e finalização incluídos.",
      "Escova" => "Higienização, proteção térmica e escova com acabamento duradouro.",
      "Coloração" => "Colorimetria personalizada, teste de mecha e selagem.",
      "Manicure" => "Esmaltação precisa, cuidado com cutículas e esterilização de materiais.",
      "Pedicure" => "Hidratação, lixamento e acabamento para conforto prolongado.",
      "Maquiagem" => "Pele bem preparada, fixação prolongada e look sob medida.",
      "Design de sobrancelhas" => "Mapeamento facial e simetria respeitando o desenho natural."
    }[sub]
  when "Fotografia"
    {
      "Ensaio externo" => "Planejamento de locação, direção leve e entrega de fotos editadas em alta.",
      "Eventos" => "Cobertura fotográfica do início ao fim, com registro espontâneo e formal.",
      "Produtos" => "Iluminação controlada, fundo neutro e consistência entre imagens.",
      "Newborn" => "Ambiente aquecido, segurança do bebê em primeiro lugar e cenário minimalista.",
      "Casamento" => "Storytelling completo do dia, making of à festa, com timeline ajustada aos noivos.",
      "Retrato corporativo" => "Retratos profissionais com orientação de pose e expressão."
    }[sub]
  when "Consultório odontológico"
    {
      "Limpeza" => "Profilaxia completa com orientação de cuidados em casa.",
      "Clareamento dental" => "Avaliação de sensibilidade e protocolo em consultório e/ou moldeira.",
      "Restauração" => "Restaurações estéticas com resina de alta performance.",
      "Tratamento de canal" => "Terapêutica endodôntica com anestesia e radiografias de controle.",
      "Ortodontia" => "Avaliação ortodôntica e planejamento com opções de aparelhos.",
      "Implante" => "Implantodontia com exames prévios e planejamento seguro."
    }[sub]
  when "Serviços domésticos"
    {
      "Faxina residencial" => "Limpeza completa com foco em cozinha, banheiros e áreas de alto tráfego.",
      "Diarista" => "Rotina de manutenção com checklist definido com o cliente.",
      "Passadoria" => "Passadoria cuidadosa com separação por tecido e vapor quando necessário.",
      "Organização" => "Dobras funcionais, setorização e etiquetas para manter a casa prática.",
      "Limpeza pós-obra" => "Remoção de resíduos, aspiração fina e detalhamento de acabamentos."
    }[sub]
  when "Pequenos reparos em casa"
    {
      "Eletricista" => "Troca de disjuntores, tomadas e instalação de luminárias com teste de carga.",
      "Encanador" => "Detecção de vazamentos, troca de sifões e desentupimentos leves.",
      "Pintura" => "Proteção de áreas, massa corrida quando necessário e acabamento uniforme.",
      "Marido de aluguel" => "Pequenas instalações, regulagens e fixações com ferramental completo.",
      "Montagem de móveis" => "Montagem limpa, alinhamento e reaperto final.",
      "Pequenos consertos" => "Ajustes diversos com orçamento rápido e transparente."
    }[sub]
  else
    "Serviço executado com processo claro, materiais adequados e atendimento pontual."
  end
end

# ---------- Usuários ----------
def random_address_from_pool
  uf = UF_SUL_SUDESTE.sample
  base = CITIES_BY_STATE[uf].sample
  {
    state: uf,
    city: base[:city],
    address: base[:address],
    address_number: "",
    cep: base[:cep].gsub(/\D/, "")
  }
end

puts "Criando profissionais..."
PRO_COUNT = 20
professionals = Array.new(PRO_COUNT) do
  addr = random_address_from_pool
  category_for_pro = CATEGORIES.sample  # <-- define a categoria desse profissional

  User.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :professional,
    profile_completed: true,
    phone_number: Faker::PhoneNumber.cell_phone_in_e164,
    description: pro_bio_for(category_for_pro, city: addr[:city]),  # <-- usa aqui
    **addr
  ).tap do |u|
    # guarda a categoria escolhida só para uso durante as seeds
    u.instance_variable_set(:@seed_category, category_for_pro)
  end
end
puts "✅ #{professionals.size} profissionais"

# --- BLOCO GARANTIDO: 1 profissional + 1 serviço por CATEGORIA ---
guaranteed_services = []
Service::CATEGORIES.each do |cat|
  addr = random_address_from_pool
  pro  = User.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :professional,
    profile_completed: true,
    phone_number: Faker::PhoneNumber.cell_phone_in_e164,
    description: pro_bio_for(cat, city: addr[:city]),
    **addr
  )
  # tenta geocodar (se seu User tiver isso)
  pro.inject_coordinates rescue nil

  sub = Service::SUBCATEGORIES[cat].sample
  srv = Service.create!(
    user: pro,
    categories: cat,
    subcategories: sub,
    name: "#{sub} – #{Faker::Company.name}",
    description: service_description_for(cat, sub),
    price_hour_cents: (rand(80..220) * 100),
    average_hours: rand(1..4)
  )
  guaranteed_services << srv

  # imagem fallback por categoria
  if (img = Service.fallback_image_for(cat))
    path = Rails.root.join("app/assets/images", img)
    if File.exist?(path)
      pro.images.attach(io: File.open(path), filename: img, content_type: "image/png")
    end
  end
end
puts "✅ Garantidos #{guaranteed_services.size} serviços (1 por categoria)"


puts "Criando clientes..."
CLI_COUNT = 40
clients = Array.new(CLI_COUNT) do
  addr = random_address_from_pool
  User.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :client,
    profile_completed: true,
    phone_number: Faker::PhoneNumber.cell_phone_in_e164,
    **addr
  )
end
puts "✅ #{clients.size} clientes"

# ---------- Serviços ----------
puts "Criando serviços (cada profissional foca em UMA categoria com várias subcategorias)..."
services = []

professionals.each do |pro|
  category = CATEGORIES.sample
  subs = SUBCATEGORIES[category].sample(rand(2..4)) # várias subcategorias na mesma categoria
  subs.each do |sub|
    s = Service.create!(
      user: pro,
      categories: category,
      subcategories: sub,
      name: "#{sub} – #{Faker::Company.name}",
      description: service_description_for(category, sub),
      price_hour_cents: (rand(60..250) * 100),       # R$60–R$250/h
      average_hours: rand(1..6)                      # ⏱️ hora cheia (1..6)
    )
    services << s
  end

  # Anexa 1 imagem por profissional (fallback por categoria)
  img = Service.fallback_image_for(category)
  img_path = Rails.root.join("app/assets/images", img)
  if File.exist?(img_path)
    pro.images.attach(
      io: File.open(img_path),
      filename: img,
      content_type: "image/png"
    )
  end
end

puts "✅ #{services.size} serviços"

# ---------- Conversas (opcional, útil pra testar inbox) ----------
puts "Criando conversas de amostra..."
conversations = []
services.sample(15).each do |s|
  client = clients.sample
  next if client.id == s.user_id
  conversations << Conversation.find_or_create_by!(
    client: client, professional: s.user, service: s
  )
end
puts "✅ #{conversations.size} conversas"

# ---------- Agendamentos (só em dias úteis, 9–18h, duração inteira em horas) ----------
def free_slot_for_provider(provider_id, duration_hours:, days_ahead: 30, open_hour: 9, close_hour: 18)
  dur = duration_hours.to_i
  raise ArgumentError, "duration_hours precisa ser >= 1" if dur < 1

  60.times do
    date = Date.current + rand(0...days_ahead).days
    next if date.saturday? || date.sunday?

    latest_start = [close_hour - dur, open_hour].max
    next if latest_start < open_hour

    hour     = rand(open_hour..latest_start)
    start_at = Time.zone.local(date.year, date.month, date.day, hour, 0, 0)
    end_at   = start_at + dur.hours

    conflict = Schedule.joins(:service)
                       .where(services: { user_id: provider_id })
                       .where("start_at < ? AND end_at > ?", end_at, start_at)
                       .exists?
    return [start_at, end_at] unless conflict
  end
  nil
end

puts "Criando agendamentos..."
SCHEDULE_COUNT = 50
created = 0
attempts = 0

while created < SCHEDULE_COUNT && attempts < SCHEDULE_COUNT * 10
  attempts += 1
  srv = services.sample
  client = clients.sample
  next if client.id == srv.user_id

  dur = (srv.average_hours.presence || rand(1..3)).to_i
  slot = free_slot_for_provider(srv.user_id, duration_hours: dur)
  next unless slot

  start_at, end_at = slot

  # Status coerente com confirmações
  status = %i[pending confirmed completed canceled no_show].sample
  accepted_client = %i[confirmed completed].include?(status)
  accepted_prof   = %i[confirmed completed].include?(status)
  confirmed       = %i[confirmed completed].include?(status)

  sch = Schedule.create!(
    user_id: client.id,                 # (seu schema tem user_id; costuma ser o cliente)
    client: client,
    professional: srv.user,
    service: srv,
    start_at: start_at,
    end_at: end_at,
    status: Schedule.statuses[status],
    accepted_client: accepted_client,
    accepted_professional: accepted_prof,
    confirmed: confirmed
  )

  # Mensagens de exemplo na thread do agendamento
  Message.create!(user: client,       schedule: sch, content: "Olá, tudo bem? Gostaria de confirmar esse horário.")
  Message.create!(user: srv.user,     schedule: sch, content: "Olá! Tudo certo. Nos vemos no horário marcado.")
  created += 1
end

puts "✅ #{created} agendamentos"

puts "Seeds concluídas!"
