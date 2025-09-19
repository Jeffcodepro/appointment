# db/seeds.rb
# encoding: utf-8
require "faker"
require "set"

Faker::Config.locale = 'pt-BR'
Faker::UniqueGenerator.clear

puts "Limpando o banco..."
Message.delete_all
Schedule.delete_all
Conversation.delete_all
Service.delete_all
User.delete_all

# =================== PARÂMETROS ===================
PROS_PER_CATEGORY = 4   # 👈 4 profissionais por categoria (mude se quiser)
SUBS_PER_PRO      = 3   # 👈 3 subcategorias por profissional

# =================== ENDEREÇOS ====================
CITIES_BY_STATE = {
  "SP" => [
    { city: "São Paulo",  address: "Avenida Paulista, 1578", cep: "01310-200" },
    { city: "Campinas",   address: "Rua Dr. Quirino, 1000",  cep: "13015-081" },
    { city: "Santos",     address: "Av. Ana Costa, 318",     cep: "11060-002" }
  ],
  "RJ" => [
    { city: "Rio de Janeiro", address: "Rua do Catete, 110",              cep: "22220-000" },
    { city: "Niterói",        address: "Rua Visconde do Rio Branco, 251", cep: "24020-006" }
  ],
  "MG" => [
    { city: "Belo Horizonte", address: "Av. Amazonas, 1830",              cep: "30180-001" },
    { city: "Uberlândia",     address: "Av. João Naves de Ávila, 1331",   cep: "38400-902" }
  ],
  "ES" => [
    { city: "Vitória",    address: "Av. Jerônimo Monteiro, 1000", cep: "29010-002" },
    { city: "Vila Velha", address: "Rua Henrique Moscoso, 1320",  cep: "29100-240" }
  ],
  "PR" => [
    { city: "Curitiba",   address: "Rua XV de Novembro, 800", cep: "80020-310" },
    { city: "Londrina",   address: "Av. Higienópolis, 1600",  cep: "86015-010" }
  ],
  "SC" => [
    { city: "Florianópolis", address: "Rua Felipe Schmidt, 600",  cep: "88010-001" },
    { city: "Joinville",     address: "Rua Nove de Março, 200",   cep: "89201-500" }
  ],
  "RS" => [
    { city: "Porto Alegre",  address: "Rua dos Andradas, 1234",   cep: "90020-007" },
    { city: "Caxias do Sul", address: "Rua Sinimbu, 200",         cep: "95020-001" }
  ]
}.freeze
UF_SUL_SUDESTE = CITIES_BY_STATE.keys

def random_address_from_pool
  uf = UF_SUL_SUDESTE.sample
  base = CITIES_BY_STATE[uf].sample
  { state: uf, city: base[:city], address: base[:address], address_number: "", cep: base[:cep].gsub(/\D/, "") }
end

# =================== DOMÍNIO ======================
CATEGORIES = [
  "Salão de beleza",
  "Fotografia",
  "Consultório odontológico",
  "Serviços domésticos",
  "Pequenos reparos em casa"
].freeze

SUBCATEGORIES = {
  "Salão de beleza" => [
    "Corte de cabelo", "Escova", "Coloração", "Manicure", "Pedicure", "Maquiagem", "Design de sobrancelhas"
  ],
  "Fotografia" => [
    "Ensaio externo", "Eventos", "Produtos", "Newborn", "Casamento", "Retrato corporativo"
  ],
  "Consultório odontológico" => [
    "Limpeza", "Clareamento dental", "Restauração", "Tratamento de canal", "Ortodontia", "Implante"
  ],
  "Serviços domésticos" => [
    "Faxina residencial", "Diarista", "Passadoria", "Organização", "Limpeza pós-obra"
  ],
  "Pequenos reparos em casa" => [
    "Eletricista", "Encanador", "Pintura", "Marido de aluguel", "Montagem de móveis", "Pequenos consertos"
  ]
}.freeze

# =================== HELPERS DE TEXTO =============
def pro_bio_for(category, city:)
  case category
  when "Salão de beleza"
    ["Profissional de beleza com mais de #{rand(3..12)} anos de experiência.",
     "Atendo em #{city} com foco em higiene, biossegurança e acabamento impecável.",
     "Trabalho com marcas profissionais e horários com agendamento."].join(" ")
  when "Fotografia"
    ["Fotógraf@ em #{city}, apaixonad@ por registrar histórias reais.",
     "Atendimento humanizado do briefing à entrega, com direção de pose leve.",
     "Equipamentos full-frame e backup de arquivos."].join(" ")
  when "Consultório odontológico"
    ["Cirurgiã(o)-dentista atuando em #{city}, atendimento acolhedor e pontual.",
     "Protocolos de esterilização e materiais de primeira linha.",
     "Planos de tratamento claros e acompanhamento pós-procedimento."].join(" ")
  when "Serviços domésticos"
    ["Profissional de limpeza e organização em #{city}.",
     "Checklists personalizados por ambiente e produtos adequados a cada superfície.",
     "Compromisso com pontualidade e discrição."].join(" ")
  when "Pequenos reparos em casa"
    ["Técnic@ de manutenção residencial em #{city}.",
     "Diagnóstico rápido, orçamento antes de iniciar e garantia do serviço.",
     "Atendimento de segunda a sábado, horário comercial."].join(" ")
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

# =============== POOL DE IMAGENS POR CATEGORIA ===============
CATEGORY_IMAGE_PATTERNS = {
  "Salão de beleza"          => "servico_saude*.{png,jpg,jpeg,webp}",
  "Fotografia"               => "servico_eventos*.{png,jpg,jpeg,webp}",
  "Consultório odontológico" => "servico_odonto*.{png,jpg,jpeg,webp}",
  "Serviços domésticos"      => "servico_servicos_domesticos*.{png,jpg,jpeg,webp}",
  "Pequenos reparos em casa" => "servico_reparo_manutencao*.{png,jpg,jpeg,webp}"
}.freeze

CATEGORY_IMAGE_FALLBACK = {
  "Salão de beleza"          => "servico_saude.png",
  "Fotografia"               => "servico_eventos.png",
  "Consultório odontológico" => "servico_odonto.png",
  "Serviços domésticos"      => "servico_servicos_domesticos.png",
  "Pequenos reparos em casa" => "servico_reparo_manutencao.png"
}.freeze

def content_type_for(filename)
  case File.extname(filename).downcase
  when ".jpg", ".jpeg" then "image/jpeg"
  when ".png"          then "image/png"
  when ".webp"         then "image/webp"
  else "application/octet-stream"
  end
end

def build_category_image_pools
  base_dir = Rails.root.join("app/assets/images")
  Hash[
    CATEGORIES.map do |cat|
      pattern = CATEGORY_IMAGE_PATTERNS[cat]
      files = Dir.glob(base_dir.join(pattern)).map { |p| File.basename(p) }
      if files.empty?
        fb = CATEGORY_IMAGE_FALLBACK[cat]
        files = [fb].compact if fb && File.exist?(base_dir.join(fb))
      end
      [cat, files.uniq]
    end
  ]
end

@category_image_pools = build_category_image_pools

# Fila por categoria: garante unicidade por rodada (round-robin)
@category_image_queue = {}
CATEGORIES.each do |cat|
  pool = @category_image_pools[cat]
  pool = [CATEGORY_IMAGE_FALLBACK[cat]].compact if pool.blank?
  @category_image_queue[cat] = pool.shuffle.dup
end

def next_unique_image_for_category(cat)
  q = @category_image_queue[cat]
  if q.empty?
    # recomeça outra rodada (se chegarmos aqui, já usamos todas pelo menos uma vez)
    q.concat(@category_image_pools[cat].shuffle)
  end
  q.shift
end

puts "Imagens detectadas por categoria:"
CATEGORIES.each { |cat| puts "  - #{cat}: #{@category_image_pools[cat].size} arquivo(s)" }

# =============== ATTACH HELPERS (banner + serviço) ===============
def attach_banner_to_user!(user, filename)
  path = Rails.root.join("app/assets/images", filename)
  return unless File.exist?(path)
  ct = content_type_for(filename)

  # banner (se existir no modelo)
  if user.respond_to?(:banner) && user.banner.respond_to?(:attach)
    user.banner.attach(io: File.open(path), filename: filename, content_type: ct)
  end

  # galeria (para index fallback)
  if user.respond_to?(:images) && user.images.respond_to?(:attach)
    user.images.attach(io: File.open(path), filename: filename, content_type: ct)
  end
end

def attach_image_to_service!(service, filename)
  return unless service.respond_to?(:image)
  path = Rails.root.join("app/assets/images", filename)
  return unless File.exist?(path)
  service.image.attach(io: File.open(path), filename: filename, content_type: content_type_for(filename))
end

# =============== NOMES ÚNICOS =====================
USED_PERSON_NAMES  = Set.new
USED_SERVICE_NAMES = Set.new
def unique_person_name
  loop do
    n = Faker::Name.unique.name
    next if USED_PERSON_NAMES.include?(n)
    USED_PERSON_NAMES << n
    return n
  end
end
def unique_company_name
  loop do
    n = Faker::Company.unique.name
    next if USED_SERVICE_NAMES.include?(n)
    USED_SERVICE_NAMES << n
    return n
  end
end

# =============== CRIA PROFISSIONAIS + SERVIÇOS (GENÉRICOS) =================
puts "Criando profissionais e serviços…"

professionals = []
services      = []

CATEGORIES.each do |cat|
  subs = SUBCATEGORIES[cat].shuffle

  PROS_PER_CATEGORY.times do
    addr = random_address_from_pool
    pro  = User.create!(
      name: unique_person_name,
      email: Faker::Internet.unique.email,
      password: "password",
      role: :professional,
      profile_completed: true,
      phone_number: Faker::PhoneNumber.cell_phone_in_e164,
      description: pro_bio_for(cat, city: addr[:city]),
      **addr
    )
    pro.inject_coordinates rescue nil
    professionals << pro

    # 1) Imagem única p/ este profissional nesta categoria
    pro_img = next_unique_image_for_category(cat)
    # 2) Usa como banner/galeria do pro
    attach_banner_to_user!(pro, pro_img)

    # 3) Cria N subcategorias para o mesmo pro, reutilizando a MESMA imagem
    chosen_subs = subs.shift(SUBS_PER_PRO)
    if chosen_subs.size < SUBS_PER_PRO
      subs = SUBCATEGORIES[cat].shuffle
      chosen_subs += subs.shift(SUBS_PER_PRO - chosen_subs.size)
    end

    chosen_subs.each do |sub|
      srv = Service.create!(
        user: pro,
        categories: cat,
        subcategories: sub,
        name: "#{sub} – #{unique_company_name}",
        description: service_description_for(cat, sub),
        price_hour_cents: (rand(80..220) * 100),
        average_hours: rand(1..4)
      )
      attach_image_to_service!(srv, pro_img)
      services << srv
    end
  end
end

puts "✅ #{professionals.size} profissionais"
puts "✅ #{services.size} serviços (mesma imagem por pro dentro da categoria; imagens diferentes entre pros)"

# =============== PROFISSIONAL FIXO: JEFFERSON (ODONTO) ===============
puts "Criando profissional fixo (Jefferson)…"
owner_email    = "jeffersonoliveirapro1212@gmail.com"
owner_password = "123456"
owner_addr     = random_address_from_pool

jefferson = User.create!(
  name: "Jefferson Oliveira",
  email: owner_email,
  password: owner_password,
  role: :professional,
  profile_completed: true,
  phone_number: Faker::PhoneNumber.cell_phone_in_e164,
  description: pro_bio_for("Consultório odontológico", city: owner_addr[:city]),
  **owner_addr
)
jefferson.inject_coordinates rescue nil
professionals << jefferson

# Uma imagem única para o Jefferson (odonto)
owner_img = next_unique_image_for_category("Consultório odontológico") || CATEGORY_IMAGE_FALLBACK["Consultório odontológico"]
attach_banner_to_user!(jefferson, owner_img)

# Cria 1 serviço para cada subcategoria de odontologia (6 no total)
odonto_subs = SUBCATEGORIES["Consultório odontológico"]
owner_services = odonto_subs.map do |sub|
  srv = Service.create!(
    user: jefferson,
    categories: "Consultório odontológico",
    subcategories: sub,
    name: "#{sub} – #{unique_company_name}",
    description: service_description_for("Consultório odontológico", sub),
    price_hour_cents: (rand(120..300) * 100),
    average_hours: rand(1..3)
  )
  attach_image_to_service!(srv, owner_img)
  services << srv
  srv
end

puts "✅ Jefferson criado com #{owner_services.size} serviços em odontologia (email: #{owner_email} / senha: #{owner_password})"

# =============== CLIENTES ========================
puts "Criando clientes..."
CLI_COUNT = 40
clients = Array.new(CLI_COUNT) do
  addr = random_address_from_pool
  User.create!(
    name: unique_person_name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :client,
    profile_completed: true,
    phone_number: Faker::PhoneNumber.cell_phone_in_e164,
    **addr
  )
end
puts "✅ #{clients.size} clientes"

# =============== CONVERSAS (amostras aleatórias) =======================
puts "Criando conversas de amostra..."
conversations = []
services.sample(15).each do |s|
  client = clients.sample
  next if client.id == s.user_id
  conversations << Conversation.find_or_create_by!(client: client, professional: s.user, service: s)
end
puts "✅ #{conversations.size} conversas"

# =============== AGENDAMENTOS ====================
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

# --- 6 agendamentos para o Jefferson, com clientes e dias diferentes ---
puts "Criando 6 agendamentos para o Jefferson..."
require 'set'
used_dates = Set.new
six_clients = clients.sample(6).uniq
six_clients += clients.sample(6) while six_clients.size < 6

owner_services_by_sub = owner_services.index_by(&:subcategories)

odonto_subs.each_with_index do |sub, i|
  srv = owner_services_by_sub[sub]
  dur = (srv.average_hours.presence || 1).to_i

  slot = nil
  40.times do
    s = free_slot_for_provider(jefferson.id, duration_hours: dur, days_ahead: 50)
    break unless s
    d = s[0].to_date
    # garante datas distintas e dias úteis
    if !used_dates.include?(d) && !d.saturday? && !d.sunday?
      slot = s
      used_dates << d
      break
    end
  end
  next unless slot
  start_at, end_at = slot
  client = six_clients[i]

  sch = Schedule.create!(
    user_id: client.id,
    client: client,
    professional: jefferson,
    service: srv,
    start_at: start_at,
    end_at: end_at,
    status: Schedule.statuses[:confirmed],
    accepted_client: true,
    accepted_professional: true,
    confirmed: true
  )

  Message.create!(user: client,    schedule: sch, content: "Olá Jefferson, gostaria de agendar #{sub.downcase}.")
  Message.create!(user: jefferson, schedule: sch, content: "Agendamento confirmado! Até lá.")
end
puts "✅ 6 agendamentos confirmados para o Jefferson"

# --- Agendamentos aleatórios (mantido) ---
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

  status = %i[pending confirmed completed canceled no_show].sample
  accepted_client = %i[confirmed completed].include?(status)
  accepted_prof   = %i[confirmed completed].include?(status)
  confirmed       = %i[confirmed completed].include?(status)

  sch = Schedule.create!(
    user_id: client.id,
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

  Message.create!(user: client,   schedule: sch, content: "Olá, tudo bem? Gostaria de confirmar esse horário.")
  Message.create!(user: srv.user, schedule: sch, content: "Olá! Tudo certo. Nos vemos no horário marcado.")
  created += 1
end

puts "✅ #{created} agendamentos aleatórios"
puts "Seeds concluídas!"
