# config/initializers/exceptions_app.rb
Rails.application.configure do
  # Usa a aplicação (rotas) para renderizar páginas de erro
  config.exceptions_app = self.routes

  # Em DEV, para pré-visualizar suas páginas via /404?preview=1 etc
  # você pode manter o padrão (consider_all_requests_local = true).
  # Para simular o comportamento de produção em dev, altere:
  # config.consider_all_requests_local = false
end
