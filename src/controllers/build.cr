class Build < Application
  # list the available files
  def index
    result = GitCommands.ls

    render json: result.select { |file|
      file.ends_with?(".cr") && !file.ends_with?("_spec.cr") && file.starts_with?("drivers/")
    }
  end

  # grab the list of available versions of file / which are built
  get "/commits" do
    driver = params["driver"]
    count = (params["id"] || 10).to_i

    render json: GitCommands.commits(driver, count)
  end

  # build a drvier, optionally based on the version specified
  def create
    driver = params["driver"]
    commit = params["commit"]? || "head"

    GitCommands.checkout(driver, commit) do
      # complile the driver
      # TODO::
    end

    head :created
  end

  # delete a built driver
  def delete
    
  end
end
