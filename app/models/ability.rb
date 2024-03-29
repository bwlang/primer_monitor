# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # See the cancancan wiki for syntax details:
  # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/Defining-Abilities.md

  def initialize(user)
    clear_aliased_actions
    alias_action :show, :show, to: :read
    alias_action :edit, to: :update

    @user = user || User.new

    guest_ability
    return if @user.new_record?

    user_ability if @user
    admin_ability if @user.role?(:administrator)
  end

  def guest_ability
    can :show, WelcomeController
    can :show, AboutController
    can :show, HelpController
    can :show, HistoryController
    can :show, Oligo
    can :show, Organism
    can %i[index show], LineagesController
    can :index, LineageVariantsController
    can :show, PrimerVariantSummariesController
    can %i[new create], User
    can %i[index read], PrimerSet, status: 'complete'
  end

  def user_ability
    can :manage, @user
    can :manage, PrimerSet, user_id: @user.id
    can :create, PrimerSet
    can %i[create destroy], PrimerSetSubscription, user_id: @user.id
    cannot :confirm, PrimerSet
  end

  def admin_ability
    can :manage, :all
    can :confirm, PrimerSet
  end
end
