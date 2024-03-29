# frozen_string_literal: true

class OrganismsController < ApplicationController
  load_and_authorize_resource
  before_action :set_organism, only: %i[show edit update destroy]

  # GET /organisms
  # GET /organisms.json
  def index
    organisms = Organism.all
    @organism_data = []
    organisms.each do |organism|
      @organism_data << { 'organism': organism, 'taxa': OrganismTaxon.where(organism_id: organism.id) }
    end
  end

  # GET /organisms/1
  # GET /organisms/1.json
  def show
    @organism = Organism.find_by(slug: params[:name])

    @config, @primer_sets = @organism.primer_sets_config

    variants_url = URI("#{@config[:data_server]}/#{@config[:organism_slug]}/lineage_variants/all.bed")

    @config[:variants_exist] = (Net::HTTP.get_response(URI(variants_url)).code == '200')
  end

  # GET /organisms/new
  def new
    @organism = Organism.new
  end

  # GET /organisms/1/edit
  def edit; end

  # POST /organisms
  # POST /organisms.json
  def create
    @organism = Organism.new(organism_params)

    respond_to do |format|
      if @organism.save
        format.html { redirect_to @organism, notice: 'Organism was successfully created.' }
        format.json { render :show, status: :created, location: @organism }
      else
        format.html { render :created }
        format.json { render json: @organism.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /organisms/1
  # PATCH/PUT /organisms/1.json
  def update
    respond_to do |format|
      if @organism.update(organism_params)
        format.html { redirect_to @organism, notice: 'Organism was successfully updated.' }
        format.json { render :show, status: :ok, location: @organism }
      else
        format.html { render :edit }
        format.json { render json: @organism.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /organisms/1
  # DELETE /organisms/1.json
  def destroy
    @organism.destroy
    respond_to do |format|
      format.html { redirect_to organisms_url, notice: 'Organism was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_organism
    @organism = Organism.find_by(name: params[:name])
  end

  # Only allow a list of trusted parameters through.
  def organism_params
    params.require(:organism).permit(:name, :alias, :slug)
  end

  def to_param
    name
  end
end
