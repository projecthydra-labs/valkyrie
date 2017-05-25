# frozen_string_literal: true
class PagesController < ApplicationController
  include Valkyrie::ControllerConcerns::ModelControllerBehavior
  self.form_class = PageForm
  self.resource_class = Page

  def model_params
    params[:page]
  end
end
