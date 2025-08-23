# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#
puts "Limpando o banco de dados..."
Message.destroy_all
Schedule.destroy_all
Service.destroy_all
User.destroy_all


# --- 1. CRIANDO USUÁRIOS (CLIENTES E PROFISSIONAIS) ---
puts "Criando 20 usuários (5 profissionais e 15 clientes)..."

# Usuários específicos para referência fácil
user_data = [
  { name: "Joao", email: "joao.cliente@email.com", password: "password", role: :professional },
  { name: "Maria", email: "maria.profissional@email.com", password: "password", role: :client, profile_completed: true }
]

# Cria 3 profissionais e 13 clientes com dados aleatórios
3.times do
  user_data << {
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :professional,
    profile_completed: true
  }
end

13.times do
  user_data << {
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: "password",
    role: :client,
  }
end

User.create!(user_data)
puts "✅ Usuários criados com sucesso!"


# --- 2. CRIANDO SERVIÇOS PROFISSIONAIS ---
puts "Criando 50 serviços..."

professional_users = User.where(role: :professional)


CATEGORIES = ["Serviços Domésticos", "Reparos e Manutenção", "Saúde e Bem-Estar", "Aulas e Cursos", "Consultoria", "Eventos"]
SUBCATEGORIES = {
  "Serviços Domésticos" => ["Limpeza", "Jardinagem", "Cozinhar"],
  "Reparos e Manutenção" => ["Elétrica", "Hidráulica", "Pintura", "Montagem de Móveis"],
  "Saúde e Bem-Estar" => ["Massagem", "Personal Trainer", "Fisioterapia"],
  "Aulas e Cursos" => ["Música", "Idiomas", "Artes Marciais"],
  "Consultoria" => ["Financeira", "Tecnológica", "Marketing"],
  "Eventos" => ["Fotografia", "Catering", "Decoração"]
}

50.times do
  category = CATEGORIES.sample
  subcategory = SUBCATEGORIES[category].sample
  Service.create!(
    name: Faker::Job.unique.title,
    description: Faker::Lorem.paragraph(sentence_count: 2),
    categories: category,
    subcategories: subcategory,
    price_hour_cents: (Faker::Commerce.price(range: 40.0..200.0) * 100).to_i, # Multiplica por 100 para converter em centavos
    mean_hours: Faker::Number.between(from: 1, to: 10),
    user: professional_users.sample
  )
end

puts "✅ #{Service.count} serviços criados com sucesso!"


# --- 3. CRIANDO AGENDAMENTOS (SCHEDULES) ---
puts "Criando 30 agendamentos..."

client_users = User.where(role: :client)
services = Service.all

30.times do
  # Seleciona um cliente e um serviço aleatórios
  client = client_users.sample
  service = services.sample

  # Define o início do agendamento (entre 8h e 18h)
  start_hour = Faker::Number.between(from: 8, to: 18)
  start_time = Time.zone.parse("#{start_hour}:00 AM")
  end_time = start_time + service.mean_hours.hours

  # Define os status de aceitação e confirmação
  accepted_client = Faker::Boolean.boolean
  accepted_professional = Faker::Boolean.boolean
  confirmed = accepted_client && accepted_professional

  Schedule.create!(
    user: client,
    service: service,
    accepted_client: accepted_client,
    accepted_professional: accepted_professional,
    start_time: start_time,
    end_time: end_time,
    confirmed: confirmed
  )
end
puts "✅ #{Schedule.count} agendamentos criados com sucesso!"


# --- 4. CRIANDO MENSAGENS PARA OS AGENDAMENTOS ---
puts "Criando 50 mensagens..."

schedules = Schedule.all

50.times do
  schedule = schedules.sample
  # Agora, selecione os usuários associados ao agendamento novamente
  client_user = schedule.user
  professional_user = schedule.service.user

  # Seleciona um dos dois usuários associados ao agendamento para a mensagem
  user = [client_user, professional_user].sample

  Message.create!(
    user: user,
    schedule: schedule,
    content: Faker::Lorem.sentence
  )
end

puts "✅ #{Message.count} mensagens criadas com sucesso!"

puts "Criando imagens para profissionais..."
  professional_users.each do |professional|
    2.times do
      professional.images.attach(
        io: File.open(Rails.root.join('app/assets/images/servico_consultoria.png')),
        filename: "servico_consultoria.png",
        content_type: "image/png"
      )
    end
  end

puts "✅ Imagens anexadas aos profissionais com sucesso!"


puts "Seeds completas!"
