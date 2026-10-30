# Mon agent : prénom, couleur, style et consignes. Le même dans tous mes clients (décision A2).
class AgentsController < ApplicationController
  include AccountScoped

  def edit
    @agent = Agent.for(Current.user)
  end

  def update
    @agent = Agent.for(Current.user)
    if @agent.update(params.expect(agent: %i[name color style instructions]))
      redirect_to edit_agent_path, notice: "#{@agent.name} est prêt."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
