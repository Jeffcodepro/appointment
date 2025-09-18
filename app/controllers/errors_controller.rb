# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  layout "errors"

  # Se seu ApplicationController exige login/CSRF por padrão, pulamos aqui
  skip_before_action :authenticate_user!, raise: false
  skip_forgery_protection

  def not_found
    render_error(
      "Página não encontrada",
      "O endereço que você tentou acessar não existe ou foi movido.",
      :not_found
    )
  end

  def forbidden
    render_error(
      "Acesso negado",
      "Você não tem permissão para ver este conteúdo.",
      :forbidden
    )
  end

  def unprocessable
    render_error(
      "Não foi possível processar sua solicitação",
      "Confira as informações enviadas e tente novamente.",
      :unprocessable_entity
    )
  end

  def internal_error
    render_error(
      "Erro interno",
      "Algo deu errado do nosso lado. Já estamos de olho por aqui.",
      :internal_server_error
    )
  end

  # Somente DEV: força um 500 real para validar a página customizada
  def force_error
    return head :not_found unless Rails.env.development?
    raise "Erro de teste (forçando 500)"
  end

  private

  # Se preview=1, responde 200 para facilitar testar no dev
  def render_error(title, message, status_sym)
    @title   = title
    @message = message

    respond_to do |format|
      format.html do
        if params[:preview].present?
          render action_name, status: :ok
        else
          render action_name, status: status_sym
        end
      end
      format.all { head status_sym }
    end
  end
end
