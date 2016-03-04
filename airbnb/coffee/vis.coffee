
root = exports ? this

Bubbles = () ->
  # standard variables accessible to
  # the rest of the functions inside Bubbles
  width = 980
  height = 500
  data = []
  node = null
  label = null
  margin = {top: 5, right: 0, bottom: 0, left: 0}
  # largest size for our bubbles
  maxRadius = 65

  # this scale will be used to size our bubbles
  rScale = d3.scale.sqrt().range([0,maxRadius])

  # I've abstracted the data value used to size each
  # into its own function. This should make it easy
  # to switch out the underlying dataset
  rValue = (d) -> parseInt(d.count)

  # function to define the 'id' of a data element
  #  - used to bind the data uniquely to the force nodes
  #   and for url creation
  #  - should make it easier to switch out dataset
  #   for your own
  idValue = (d) -> d.name

  # function to define what to display in each bubble
  #  again, abstracted to ease migration to
  #  a different dataset if desired
  textValue = (d) -> d.name

  # constants to control how
  # collision look and act
  collisionPadding = 4
  minCollisionRadius = 12

  # variables that can be changed
  # to tweak how the force layout
  # acts
  # - jitter controls the 'jumpiness'
  #  of the collisions
  jitter = 0.5

  # ---
  # tweaks our dataset to get it into the
  # format we want
  # - for this dataset, we just need to
  #  ensure the count is a number
  # - for your own dataset, you might want
  #  to tweak a bit more
  # ---
  transformData = (rawData) ->
    rawData.forEach (d) ->
      d.count = parseInt(d.count)
      rawData.sort(() -> 0.5 - Math.random())
    rawData

  # ---
  # tick callback function will be executed for every
  # iteration of the force simulation
  # - moves force nodes towards their destinations
  # - deals with collisions of force nodes
  # - updates visual bubbles to reflect new force node locations
  # ---
  tick = (e) ->
    dampenedAlpha = e.alpha * 0.1

    # Most of the work is done by the gravity and collide
    # functions.
    node
      .each(gravity(dampenedAlpha))
      .each(collide(jitter))
      .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    # As the labels are created in raw html and not svg, we need
    # to ensure we specify the 'px' for moving based on pixels
    label
      .style("left", (d) -> ((margin.left + d.x) - d.dx / 2) + "px")
      .style("top", (d) -> ((margin.top + d.y) - d.dy / 2) + "px")

  # The force variable is the force layout controlling the bubbles
  # here we disable gravity and charge as we implement custom versions
  # of gravity and collisions for this visualization
  force = d3.layout.force()
    .gravity(0)
    .charge(0)
    .size([width, height])
    .on("tick", tick)

  # ---
  # Creates new chart function. This is the 'constructor' of our
  #  visualization
  # Check out http://bost.ocks.org/mike/chart/
  #  for a explanation and rational behind this function design
  # ---
  chart = (selection) ->
    selection.each (rawData) ->

      # first, get the data in the right format
      data = transformData(rawData)
      # setup the radius scale's domain now that
      # we have some data
      maxDomainValue = d3.max(data, (d) -> rValue(d))
      rScale.domain([0, maxDomainValue])

      # a fancy way to setup svg element
      svg = d3.select(this).selectAll("svg").data([data])
      svgEnter = svg.enter().append("svg")
      svg.attr("width", "100%" )
      # svg.attr("height", "100%" )

      # svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )

      # node will be used to group the bubbles
      node = svgEnter.append("g").attr("id", "bubble-nodes")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      # clickable background rect to clear the current selection
      node.append("rect")
        .attr("id", "bubble-background")
        .attr("width", width)
        .attr("height", height)
        .on("click", clear)

      # label is the container div for all the labels that sit on top of
      # the bubbles
      # - remember that we are keeping the labels in plain html and
      #  the bubbles in svg
      label = d3.select(this).selectAll("#bubble-labels").data([data])
        .enter()
        .append("div")
        .attr("id", "bubble-labels")

      update()

      # see if url includes an id already
      hashchange()

      # automatically call hashchange when the url has changed
      d3.select(window)
        .on("hashchange", hashchange)

  # ---
  # update starts up the force directed layout and then
  # updates the nodes and labels
  # ---
  update = () ->
    # add a radius to our data nodes that will serve to determine
    # when a collision has occurred. This uses the same scale as
    # the one used to size our bubbles, but it kicks up the minimum
    # size to make it so smaller bubbles have a slightly larger
    # collision 'sphere'
    data.forEach (d,i) ->
      d.forceR = Math.max(minCollisionRadius, rScale(rValue(d)))

    # start up the force layout
    force.nodes(data).start()

    # call our update methods to do the creation and layout work
    updateNodes()
    updateLabels()

  # ---
  # updateNodes creates a new bubble for each node in our dataset
  # ---
  updateNodes = () ->
    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    node = node.selectAll(".bubble-node").data(data, (d) -> idValue(d))

    # we don't actually remove any nodes from our data in this example
    # but if we did, this line of code would remove them from the
    # visualization as well
    node.exit().remove()

    # nodes are just links with circles inside.
    # the styling comes from the css
    node.enter()
      .append("a")
      .attr("class", "bubble-node")
      .attr("xlink:href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(connectEvents)
      .append("circle")
      .attr("r", (d) -> rScale(rValue(d)))

  # ---
  # updateLabels is more involved as we need to deal with getting the sizing
  # to work well with the font size
  # ---
  updateLabels = () ->
    # as in updateNodes, we use idValue to define what the unique id for each data
    # point is
    label = label.selectAll(".bubble-label").data(data, (d) -> idValue(d))

    label.exit().remove()

    # labels are anchors with div's inside them
    # labelEnter holds our enter selection so it
    # is easier to append multiple elements to this selection
    labelEnter = label.enter().append("a")
      .attr("class", "bubble-label")
      .attr("href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(connectEvents)

    labelEnter.append("div")
      .attr("class", "bubble-label-name")
      .text((d) -> textValue(d))

    # labelEnter.append("div")
    #   .attr("class", "bubble-label-value")
    #   .text((d) -> rValue(d))

    # label font size is determined based on the size of the bubble
    # this sizing allows for a bit of overhang outside of the bubble
    # - remember to add the 'px' at the end as we are dealing with
    #  styling divs
    label
      .style("font-size", (d) -> Math.max(8, rScale(rValue(d) / 2)) + "px")
      .style("width", (d) -> 2.5 * rScale(rValue(d)) + "px")

    # interesting hack to get the 'true' text width
    # - create a span inside the label
    # - add the text to this span
    # - use the span to compute the nodes 'dx' value
    #  which is how much to adjust the label by when
    #  positioning it
    # - remove the extra span
    label.append("span")
      .text((d) -> textValue(d))
      .each((d) -> d.dx = Math.max(2.5 * rScale(rValue(d)), this.getBoundingClientRect().width))
      .remove()

    # reset the width of the label to the actual width
    label
      .style("width", (d) -> d.dx + "px")

    # compute and store each nodes 'dy' value - the
    # amount to shift the label down
    # 'this' inside of D3's each refers to the actual DOM element
    # connected to the data node
    label.each((d) -> d.dy = this.getBoundingClientRect().height)

  # ---
  # custom gravity to skew the bubble placement
  # ---
  gravity = (alpha) ->
    # start with the center of the display
    cx = width / 2
    cy = height / 2
    # use alpha to affect how much to push
    # towards the horizontal or vertical
    ax = alpha / 8
    ay = alpha

    # return a function that will modify the
    # node's x and y values
    (d) ->
      d.x += (cx - d.x) * ax
      d.y += (cy - d.y) * ay

  # ---
  # custom collision function to prevent
  # nodes from touching
  # This version is brute force
  # we could use quadtree to speed up implementation
  # (which is what Mike's original version does)
  # ---
  collide = (jitter) ->
    # return a function that modifies
    # the x and y of a node
    (d) ->
      data.forEach (d2) ->
        # check that we aren't comparing a node
        # with itself
        if d != d2
          # use distance formula to find distance
          # between two nodes
          x = d.x - d2.x
          y = d.y - d2.y
          distance = Math.sqrt(x * x + y * y)
          # find current minimum space between two nodes
          # using the forceR that was set to match the
          # visible radius of the nodes
          minDistance = d.forceR + d2.forceR + collisionPadding

          # if the current distance is less then the minimum
          # allowed then we need to push both nodes away from one another
          if distance < minDistance
            # scale the distance based on the jitter variable
            distance = (distance - minDistance) / distance * jitter
            # move our two nodes
            moveX = x * distance
            moveY = y * distance
            d.x -= moveX
            d.y -= moveY
            d2.x += moveX
            d2.y += moveY

  # ---
  # adds mouse events to element
  # ---
  connectEvents = (d) ->
    d.on("click", click)
    d.on("mouseover", mouseover)
    d.on("mouseout", mouseout)

  # ---
  # clears currently selected bubble
  # ---
  clear = () ->
    location.replace("#")

  # ---
  # changes clicked bubble by modifying url
  # ---
  click = (d) ->
    location.replace("#" + encodeURIComponent(idValue(d)))
    d3.event.preventDefault()

  # ---
  # called when url after the # changes
  # ---
  hashchange = () ->
    id = decodeURIComponent(location.hash.substring(1)).trim()
    updateActive(id)

  # ---
  # activates new node
  # ---
  updateActive = (id) ->
    node.classed("bubble-selected", (d) -> id == idValue(d))
    # if no node is selected, id will be empty
    if id.length > 0
      d3.select("#status").html("<h3>The word <span class=\"active\">#{id}</span> is now active</h3>")
    else
      d3.select("#status").html("<h3>No word is active</h3>")

  # ---
  # hover event
  # ---
  mouseover = (d) ->
    node.classed("bubble-hover", (p) -> p == d)

  # ---
  # remove hover class
  # ---
  mouseout = (d) ->
    node.classed("bubble-hover", false)

  # ---
  # public getter/setter for jitter variable
  # ---
  chart.jitter = (_) ->
    if !arguments.length
      return jitter
    jitter = _
    force.start()
    chart

  # ---
  # public getter/setter for height variable
  # ---
  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  # ---
  # public getter/setter for width variable
  # ---
  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  # ---
  # public getter/setter for radius function
  # ---
  chart.r = (_) ->
    if !arguments.length
      return rValue
    rValue = _
    chart

  # final act of our main function is to
  # return the chart function we have created
  return chart

# ---
# Helper function that simplifies the calling
# of our chart with it's data and div selector
# specified
# ---
root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

texts = [
  {key:"midtown", file:"midtown.csv", name:"Midtown", num:"10485 reviews", pos:"Average 'positive sentiment' per review: 67.85", stars:"Average star rating: 4.59"}
  {key:"allerton", file:"allerton.csv", name:"Allerton", num:"456 reviews", pos:"Average 'positive sentiment' per review: 66.24", stars:"Average star rating: 4.53"}
{key:"ardenheights", file:"ardenheights.csv", name:"Arden Heights", num:"24 reviews", pos:"Average 'positive sentiment' per review: 71.8", stars:"Average star rating: 4.96"}
{key:"arrochar", file:"arrochar.csv", name:"Arrochar", num:"12 reviews", pos:"Average 'positive sentiment' per review: 75.68", stars:"Average star rating: 4.92"}
{key:"arverne", file:"arverne.csv", name:"Arverne", num:"495 reviews", pos:"Average 'positive sentiment' per review: 69.17", stars:"Average star rating: 4.74"}
{key:"astoria", file:"astoria.csv", name:"Astoria", num:"7038 reviews", pos:"Average 'positive sentiment' per review: 67.84", stars:"Average star rating: 4.63"}
{key:"bathbeach", file:"bathbeach.csv", name:"Bath Beach", num:"26 reviews", pos:"Average 'positive sentiment' per review: 68.39", stars:"Average star rating: 4.88"}
{key:"batteryparkcity", file:"batteryparkcity.csv", name:"Battery Park City", num:"563 reviews", pos:"Average 'positive sentiment' per review: 70.03", stars:"Average star rating: 4.67"}
{key:"bayridge", file:"bayridge.csv", name:"Bay Ridge", num:"522 reviews", pos:"Average 'positive sentiment' per review: 68.81", stars:"Average star rating: 4.67"}
{key:"bayterrace", file:"bayterrace.csv", name:"Bay Terrace", num:"43 reviews", pos:"Average 'positive sentiment' per review: 67.45", stars:"Average star rating: 4.71"}
{key:"bayterrace,statenisland", file:"bayterrace,statenisland.csv", name:"Bay Terrace, Staten Island", num:"6 reviews", pos:"Average 'positive sentiment' per review: 68.63", stars:"Average star rating: 4.5"}
{key:"baychester", file:"baychester.csv", name:"Baychester", num:"1 reviews", pos:"Average 'positive sentiment' per review: 56.48", stars:"Average star rating: 3.0"}
{key:"bayside", file:"bayside.csv", name:"Bayside", num:"57 reviews", pos:"Average 'positive sentiment' per review: 68.62", stars:"Average star rating: 4.46"}
{key:"bayswater", file:"bayswater.csv", name:"Bayswater", num:"61 reviews", pos:"Average 'positive sentiment' per review: 68.68", stars:"Average star rating: 4.55"}
{key:"bedford-stuyvesant", file:"bedford-stuyvesant.csv", name:"Bedford-Stuyvesant", num:"28302 reviews", pos:"Average 'positive sentiment' per review: 67.5", stars:"Average star rating: 4.56"}
{key:"belleharbor", file:"belleharbor.csv", name:"Belle Harbor", num:"1 reviews", pos:"Average 'positive sentiment' per review: 67.32", stars:"Average star rating: 5.0"}
{key:"bellerose", file:"bellerose.csv", name:"Bellerose", num:"33 reviews", pos:"Average 'positive sentiment' per review: 67.69", stars:"Average star rating: 4.2"}
{key:"belmont", file:"belmont.csv", name:"Belmont", num:"85 reviews", pos:"Average 'positive sentiment' per review: 69.15", stars:"Average star rating: 4.4"}
{key:"bensonhurst", file:"bensonhurst.csv", name:"Bensonhurst", num:"246 reviews", pos:"Average 'positive sentiment' per review: 66.65", stars:"Average star rating: 4.58"}
{key:"bergenbeach", file:"bergenbeach.csv", name:"Bergen Beach", num:"23 reviews", pos:"Average 'positive sentiment' per review: 67.51", stars:"Average star rating: 4.52"}
{key:"boerumhill", file:"boerumhill.csv", name:"Boerum Hill", num:"1866 reviews", pos:"Average 'positive sentiment' per review: 69.33", stars:"Average star rating: 4.73"}
{key:"boroughpark", file:"boroughpark.csv", name:"Borough Park", num:"611 reviews", pos:"Average 'positive sentiment' per review: 66.28", stars:"Average star rating: 4.26"}
{key:"briarwood", file:"briarwood.csv", name:"Briarwood", num:"251 reviews", pos:"Average 'positive sentiment' per review: 68.13", stars:"Average star rating: 4.74"}
{key:"brightonbeach", file:"brightonbeach.csv", name:"Brighton Beach", num:"288 reviews", pos:"Average 'positive sentiment' per review: 67.38", stars:"Average star rating: 4.62"}
{key:"bronxdale", file:"bronxdale.csv", name:"Bronxdale", num:"33 reviews", pos:"Average 'positive sentiment' per review: 68.69", stars:"Average star rating: 4.88"}
{key:"brooklynheights", file:"brooklynheights.csv", name:"Brooklyn Heights", num:"1425 reviews", pos:"Average 'positive sentiment' per review: 69.82", stars:"Average star rating: 4.7"}
{key:"brownsville", file:"brownsville.csv", name:"Brownsville", num:"275 reviews", pos:"Average 'positive sentiment' per review: 68.09", stars:"Average star rating: 4.48"}
{key:"bushwick", file:"bushwick.csv", name:"Bushwick", num:"16061 reviews", pos:"Average 'positive sentiment' per review: 67.99", stars:"Average star rating: 4.58"}
{key:"cambriaheights", file:"cambriaheights.csv", name:"Cambria Heights", num:"41 reviews", pos:"Average 'positive sentiment' per review: 68.02", stars:"Average star rating: 4.65"}
{key:"canarsie", file:"canarsie.csv", name:"Canarsie", num:"711 reviews", pos:"Average 'positive sentiment' per review: 66.81", stars:"Average star rating: 4.55"}
{key:"carrollgardens", file:"carrollgardens.csv", name:"Carroll Gardens", num:"1617 reviews", pos:"Average 'positive sentiment' per review: 69.79", stars:"Average star rating: 4.7"}
{key:"castletoncorners", file:"castletoncorners.csv", name:"Castleton Corners", num:"47 reviews", pos:"Average 'positive sentiment' per review: 67.53", stars:"Average star rating: 4.73"}
{key:"chelsea", file:"chelsea.csv", name:"Chelsea", num:"13774 reviews", pos:"Average 'positive sentiment' per review: 69.01", stars:"Average star rating: 4.64"}
{key:"chinatown", file:"chinatown.csv", name:"Chinatown", num:"4475 reviews", pos:"Average 'positive sentiment' per review: 68.18", stars:"Average star rating: 4.55"}
{key:"cityisland", file:"cityisland.csv", name:"City Island", num:"147 reviews", pos:"Average 'positive sentiment' per review: 68.16", stars:"Average star rating: 4.82"}
{key:"civiccenter", file:"civiccenter.csv", name:"Civic Center", num:"268 reviews", pos:"Average 'positive sentiment' per review: 68.55", stars:"Average star rating: 4.64"}
{key:"claremontvillage", file:"claremontvillage.csv", name:"Claremont Village", num:"210 reviews", pos:"Average 'positive sentiment' per review: 68.11", stars:"Average star rating: 4.61"}
{key:"clasonpoint", file:"clasonpoint.csv", name:"Clason Point", num:"36 reviews", pos:"Average 'positive sentiment' per review: 67.53", stars:"Average star rating: 4.65"}
{key:"clifton", file:"clifton.csv", name:"Clifton", num:"157 reviews", pos:"Average 'positive sentiment' per review: 65.19", stars:"Average star rating: 4.73"}
{key:"clintonhill", file:"clintonhill.csv", name:"Clinton Hill", num:"6409 reviews", pos:"Average 'positive sentiment' per review: 69.04", stars:"Average star rating: 4.65"}
{key:"co-opcity", file:"co-opcity.csv", name:"Co-op City", num:"27 reviews", pos:"Average 'positive sentiment' per review: 67.22", stars:"Average star rating: 4.78"}
{key:"cobblehill", file:"cobblehill.csv", name:"Cobble Hill", num:"1001 reviews", pos:"Average 'positive sentiment' per review: 70.76", stars:"Average star rating: 4.76"}
{key:"collegepoint", file:"collegepoint.csv", name:"College Point", num:"20 reviews", pos:"Average 'positive sentiment' per review: 70.96", stars:"Average star rating: 4.95"}
{key:"columbiast", file:"columbiast.csv", name:"Columbia St", num:"411 reviews", pos:"Average 'positive sentiment' per review: 67.75", stars:"Average star rating: 4.54"}
{key:"concord", file:"concord.csv", name:"Concord", num:"154 reviews", pos:"Average 'positive sentiment' per review: 70.09", stars:"Average star rating: 4.64"}
{key:"concourse", file:"concourse.csv", name:"Concourse", num:"397 reviews", pos:"Average 'positive sentiment' per review: 66.73", stars:"Average star rating: 4.57"}
{key:"concoursevillage", file:"concoursevillage.csv", name:"Concourse Village", num:"166 reviews", pos:"Average 'positive sentiment' per review: 64.99", stars:"Average star rating: 4.25"}
{key:"coneyisland", file:"coneyisland.csv", name:"Coney Island", num:"84 reviews", pos:"Average 'positive sentiment' per review: 70.78", stars:"Average star rating: 4.63"}
{key:"corona", file:"corona.csv", name:"Corona", num:"362 reviews", pos:"Average 'positive sentiment' per review: 66.82", stars:"Average star rating: 4.5"}
{key:"countryclub", file:"countryclub.csv", name:"Country Club", num:"30 reviews", pos:"Average 'positive sentiment' per review: 69.41", stars:"Average star rating: 4.85"}
{key:"crownheights", file:"crownheights.csv", name:"Crown Heights", num:"11861 reviews", pos:"Average 'positive sentiment' per review: 68.1", stars:"Average star rating: 4.6"}
{key:"cypresshills", file:"cypresshills.csv", name:"Cypress Hills", num:"606 reviews", pos:"Average 'positive sentiment' per review: 67.54", stars:"Average star rating: 4.51"}
{key:"dumbo", file:"dumbo.csv", name:"DUMBO", num:"368 reviews", pos:"Average 'positive sentiment' per review: 70.67", stars:"Average star rating: 4.76"}
{key:"ditmarssteinway", file:"ditmarssteinway.csv", name:"Ditmars Steinway", num:"2328 reviews", pos:"Average 'positive sentiment' per review: 67.75", stars:"Average star rating: 4.62"}
{key:"donganhills", file:"donganhills.csv", name:"Dongan Hills", num:"10 reviews", pos:"Average 'positive sentiment' per review: 76.34", stars:"Average star rating: 5.0"}
{key:"downtownbrooklyn", file:"downtownbrooklyn.csv", name:"Downtown Brooklyn", num:"654 reviews", pos:"Average 'positive sentiment' per review: 69.37", stars:"Average star rating: 4.65"}
{key:"dykerheights", file:"dykerheights.csv", name:"Dyker Heights", num:"135 reviews", pos:"Average 'positive sentiment' per review: 68.03", stars:"Average star rating: 4.3"}
{key:"eastelmhurst", file:"eastelmhurst.csv", name:"East Elmhurst", num:"1059 reviews", pos:"Average 'positive sentiment' per review: 67.25", stars:"Average star rating: 4.67"}
{key:"eastflatbush", file:"eastflatbush.csv", name:"East Flatbush", num:"1871 reviews", pos:"Average 'positive sentiment' per review: 67.68", stars:"Average star rating: 4.51"}
{key:"eastharlem", file:"eastharlem.csv", name:"East Harlem", num:"12839 reviews", pos:"Average 'positive sentiment' per review: 66.15", stars:"Average star rating: 4.5"}
{key:"eastmorrisania", file:"eastmorrisania.csv", name:"East Morrisania", num:"13 reviews", pos:"Average 'positive sentiment' per review: 63.59", stars:"Average star rating: 4.23"}
{key:"eastnewyork", file:"eastnewyork.csv", name:"East New York", num:"910 reviews", pos:"Average 'positive sentiment' per review: 66.29", stars:"Average star rating: 4.5"}
{key:"eastvillage", file:"eastvillage.csv", name:"East Village", num:"28959 reviews", pos:"Average 'positive sentiment' per review: 68.78", stars:"Average star rating: 4.58"}
{key:"eastchester", file:"eastchester.csv", name:"Eastchester", num:"38 reviews", pos:"Average 'positive sentiment' per review: 66.89", stars:"Average star rating: 4.76"}
{key:"elmhurst", file:"elmhurst.csv", name:"Elmhurst", num:"728 reviews", pos:"Average 'positive sentiment' per review: 66.09", stars:"Average star rating: 4.53"}
{key:"eltingville", file:"eltingville.csv", name:"Eltingville", num:"44 reviews", pos:"Average 'positive sentiment' per review: 71.0", stars:"Average star rating: 4.8"}
{key:"emersonhill", file:"emersonhill.csv", name:"Emerson Hill", num:"60 reviews", pos:"Average 'positive sentiment' per review: 65.81", stars:"Average star rating: 4.44"}
{key:"farrockaway", file:"farrockaway.csv", name:"Far Rockaway", num:"61 reviews", pos:"Average 'positive sentiment' per review: 66.63", stars:"Average star rating: 4.62"}
{key:"fieldston", file:"fieldston.csv", name:"Fieldston", num:"8 reviews", pos:"Average 'positive sentiment' per review: 72.25", stars:"Average star rating: 4.89"}
{key:"financialdistrict", file:"financialdistrict.csv", name:"Financial District", num:"2045 reviews", pos:"Average 'positive sentiment' per review: 69.74", stars:"Average star rating: 4.74"}
{key:"flatbush", file:"flatbush.csv", name:"Flatbush", num:"3888 reviews", pos:"Average 'positive sentiment' per review: 68.47", stars:"Average star rating: 4.63"}
{key:"flatirondistrict", file:"flatirondistrict.csv", name:"Flatiron District", num:"917 reviews", pos:"Average 'positive sentiment' per review: 69.94", stars:"Average star rating: 4.72"}
{key:"flatlands", file:"flatlands.csv", name:"Flatlands", num:"226 reviews", pos:"Average 'positive sentiment' per review: 66.16", stars:"Average star rating: 4.54"}
{key:"flushing", file:"flushing.csv", name:"Flushing", num:"1773 reviews", pos:"Average 'positive sentiment' per review: 67.0", stars:"Average star rating: 4.54"}
{key:"fordham", file:"fordham.csv", name:"Fordham", num:"98 reviews", pos:"Average 'positive sentiment' per review: 68.39", stars:"Average star rating: 4.76"}
{key:"foresthills", file:"foresthills.csv", name:"Forest Hills", num:"616 reviews", pos:"Average 'positive sentiment' per review: 68.46", stars:"Average star rating: 4.58"}
{key:"fortgreene", file:"fortgreene.csv", name:"Fort Greene", num:"6104 reviews", pos:"Average 'positive sentiment' per review: 69.31", stars:"Average star rating: 4.69"}
{key:"forthamilton", file:"forthamilton.csv", name:"Fort Hamilton", num:"176 reviews", pos:"Average 'positive sentiment' per review: 68.39", stars:"Average star rating: 4.6"}
{key:"freshmeadows", file:"freshmeadows.csv", name:"Fresh Meadows", num:"13 reviews", pos:"Average 'positive sentiment' per review: 70.31", stars:"Average star rating: 4.54"}
{key:"gerritsenbeach", file:"gerritsenbeach.csv", name:"Gerritsen Beach", num:"30 reviews", pos:"Average 'positive sentiment' per review: 64.14", stars:"Average star rating: 4.25"}
{key:"glendale", file:"glendale.csv", name:"Glendale", num:"78 reviews", pos:"Average 'positive sentiment' per review: 69.12", stars:"Average star rating: 4.89"}
{key:"gowanus", file:"gowanus.csv", name:"Gowanus", num:"1903 reviews", pos:"Average 'positive sentiment' per review: 68.85", stars:"Average star rating: 4.68"}
{key:"gramercy", file:"gramercy.csv", name:"Gramercy", num:"3206 reviews", pos:"Average 'positive sentiment' per review: 69.01", stars:"Average star rating: 4.64"}
{key:"graniteville", file:"graniteville.csv", name:"Graniteville", num:"70 reviews", pos:"Average 'positive sentiment' per review: 68.13", stars:"Average star rating: 4.66"}
{key:"gravesend", file:"gravesend.csv", name:"Gravesend", num:"88 reviews", pos:"Average 'positive sentiment' per review: 69.24", stars:"Average star rating: 4.77"}
{key:"greatkills", file:"greatkills.csv", name:"Great Kills", num:"8 reviews", pos:"Average 'positive sentiment' per review: 66.76", stars:"Average star rating: 5.0"}
{key:"greenpoint", file:"greenpoint.csv", name:"Greenpoint", num:"7720 reviews", pos:"Average 'positive sentiment' per review: 69.94", stars:"Average star rating: 4.71"}
{key:"greenwichvillage", file:"greenwichvillage.csv", name:"Greenwich Village", num:"5623 reviews", pos:"Average 'positive sentiment' per review: 69.22", stars:"Average star rating: 4.6"}
{key:"grymeshill", file:"grymeshill.csv", name:"Grymes Hill", num:"12 reviews", pos:"Average 'positive sentiment' per review: 70.35", stars:"Average star rating: 4.91"}
{key:"harlem", file:"harlem.csv", name:"Harlem", num:"26742 reviews", pos:"Average 'positive sentiment' per review: 67.19", stars:"Average star rating: 4.6"}
{key:"hell'skitchen", file:"hell'skitchen.csv", name:"Hell's Kitchen", num:"19833 reviews", pos:"Average 'positive sentiment' per review: 67.51", stars:"Average star rating: 4.55"}
{key:"highbridge", file:"highbridge.csv", name:"Highbridge", num:"137 reviews", pos:"Average 'positive sentiment' per review: 70.27", stars:"Average star rating: 4.7"}
{key:"hollis", file:"hollis.csv", name:"Hollis", num:"17 reviews", pos:"Average 'positive sentiment' per review: 67.24", stars:"Average star rating: 3.98"}
{key:"hollishills", file:"hollishills.csv", name:"Hollis Hills", num:"14 reviews", pos:"Average 'positive sentiment' per review: 66.53", stars:"Average star rating: 4.8"}
{key:"holliswood", file:"holliswood.csv", name:"Holliswood", num:"3 reviews", pos:"Average 'positive sentiment' per review: 61.28", stars:"Average star rating: 4.67"}
{key:"howardbeach", file:"howardbeach.csv", name:"Howard Beach", num:"12 reviews", pos:"Average 'positive sentiment' per review: 62.56", stars:"Average star rating: 4.25"}
{key:"huntspoint", file:"huntspoint.csv", name:"Hunts Point", num:"5 reviews", pos:"Average 'positive sentiment' per review: 69.34", stars:"Average star rating: 4.4"}
{key:"inwood", file:"inwood.csv", name:"Inwood", num:"1827 reviews", pos:"Average 'positive sentiment' per review: 67.0", stars:"Average star rating: 4.55"}
{key:"jacksonheights", file:"jacksonheights.csv", name:"Jackson Heights", num:"1730 reviews", pos:"Average 'positive sentiment' per review: 67.32", stars:"Average star rating: 4.56"}
{key:"jamaica", file:"jamaica.csv", name:"Jamaica", num:"811 reviews", pos:"Average 'positive sentiment' per review: 66.89", stars:"Average star rating: 4.45"}
{key:"jamaicaestates", file:"jamaicaestates.csv", name:"Jamaica Estates", num:"82 reviews", pos:"Average 'positive sentiment' per review: 67.37", stars:"Average star rating: 4.41"}
{key:"jamaicahills", file:"jamaicahills.csv", name:"Jamaica Hills", num:"10 reviews", pos:"Average 'positive sentiment' per review: 70.13", stars:"Average star rating: 4.0"}
{key:"kensington", file:"kensington.csv", name:"Kensington", num:"831 reviews", pos:"Average 'positive sentiment' per review: 68.74", stars:"Average star rating: 4.68"}
{key:"kewgardens", file:"kewgardens.csv", name:"Kew Gardens", num:"255 reviews", pos:"Average 'positive sentiment' per review: 67.79", stars:"Average star rating: 4.52"}
{key:"kewgardenshills", file:"kewgardenshills.csv", name:"Kew Gardens Hills", num:"63 reviews", pos:"Average 'positive sentiment' per review: 66.48", stars:"Average star rating: 4.42"}
{key:"kingsbridge", file:"kingsbridge.csv", name:"Kingsbridge", num:"99 reviews", pos:"Average 'positive sentiment' per review: 70.89", stars:"Average star rating: 4.65"}
{key:"kipsbay", file:"kipsbay.csv", name:"Kips Bay", num:"4019 reviews", pos:"Average 'positive sentiment' per review: 68.13", stars:"Average star rating: 4.56"}
{key:"laurelton", file:"laurelton.csv", name:"Laurelton", num:"44 reviews", pos:"Average 'positive sentiment' per review: 69.11", stars:"Average star rating: 4.46"}
{key:"lighthousehill", file:"lighthousehill.csv", name:"Lighthouse Hill", num:"11 reviews", pos:"Average 'positive sentiment' per review: 72.16", stars:"Average star rating: 4.65"}
{key:"littleitaly", file:"littleitaly.csv", name:"Little Italy", num:"1177 reviews", pos:"Average 'positive sentiment' per review: 67.87", stars:"Average star rating: 4.53"}
{key:"longislandcity", file:"longislandcity.csv", name:"Long Island City", num:"5062 reviews", pos:"Average 'positive sentiment' per review: 67.34", stars:"Average star rating: 4.59"}
{key:"longwood", file:"longwood.csv", name:"Longwood", num:"159 reviews", pos:"Average 'positive sentiment' per review: 67.14", stars:"Average star rating: 4.61"}
{key:"lowereastside", file:"lowereastside.csv", name:"Lower East Side", num:"14713 reviews", pos:"Average 'positive sentiment' per review: 68.61", stars:"Average star rating: 4.58"}
{key:"manhattanbeach", file:"manhattanbeach.csv", name:"Manhattan Beach", num:"61 reviews", pos:"Average 'positive sentiment' per review: 66.68", stars:"Average star rating: 4.82"}
{key:"marblehill", file:"marblehill.csv", name:"Marble Hill", num:"79 reviews", pos:"Average 'positive sentiment' per review: 67.27", stars:"Average star rating: 4.89"}
{key:"marinersharbor", file:"marinersharbor.csv", name:"Mariners Harbor", num:"136 reviews", pos:"Average 'positive sentiment' per review: 68.33", stars:"Average star rating: 4.75"}
{key:"maspeth", file:"maspeth.csv", name:"Maspeth", num:"392 reviews", pos:"Average 'positive sentiment' per review: 66.17", stars:"Average star rating: 4.46"}
{key:"melrose", file:"melrose.csv", name:"Melrose", num:"48 reviews", pos:"Average 'positive sentiment' per review: 67.08", stars:"Average star rating: 4.14"}
{key:"middlevillage", file:"middlevillage.csv", name:"Middle Village", num:"174 reviews", pos:"Average 'positive sentiment' per review: 66.63", stars:"Average star rating: 4.65"}
{key:"midlandbeach", file:"midlandbeach.csv", name:"Midland Beach", num:"36 reviews", pos:"Average 'positive sentiment' per review: 67.68", stars:"Average star rating: 4.51"}
# {key:"midtown", file:"midtown.csv", name:"Midtown", num:"10485 reviews", pos:"Average 'positive sentiment' per review: 67.85", stars:"Average star rating: 4.59"}
{key:"midwood", file:"midwood.csv", name:"Midwood", num:"490 reviews", pos:"Average 'positive sentiment' per review: 67.81", stars:"Average star rating: 4.65"}
{key:"millbasin", file:"millbasin.csv", name:"Mill Basin", num:"2 reviews", pos:"Average 'positive sentiment' per review: 70.23", stars:"Average star rating: 4.0"}
{key:"morningsideheights", file:"morningsideheights.csv", name:"Morningside Heights", num:"1900 reviews", pos:"Average 'positive sentiment' per review: 68.17", stars:"Average star rating: 4.59"}
{key:"morrisheights", file:"morrisheights.csv", name:"Morris Heights", num:"102 reviews", pos:"Average 'positive sentiment' per review: 66.34", stars:"Average star rating: 4.44"}
{key:"morrispark", file:"morrispark.csv", name:"Morris Park", num:"209 reviews", pos:"Average 'positive sentiment' per review: 67.89", stars:"Average star rating: 4.41"}
{key:"morrisania", file:"morrisania.csv", name:"Morrisania", num:"34 reviews", pos:"Average 'positive sentiment' per review: 65.21", stars:"Average star rating: 4.09"}
{key:"motthaven", file:"motthaven.csv", name:"Mott Haven", num:"495 reviews", pos:"Average 'positive sentiment' per review: 67.4", stars:"Average star rating: 4.71"}
{key:"mounthope", file:"mounthope.csv", name:"Mount Hope", num:"95 reviews", pos:"Average 'positive sentiment' per review: 68.26", stars:"Average star rating: 4.68"}
{key:"murrayhill", file:"murrayhill.csv", name:"Murray Hill", num:"2201 reviews", pos:"Average 'positive sentiment' per review: 67.97", stars:"Average star rating: 4.56"}
{key:"navyyard", file:"navyyard.csv", name:"Navy Yard", num:"43 reviews", pos:"Average 'positive sentiment' per review: 70.2", stars:"Average star rating: 4.73"}
{key:"neponsit", file:"neponsit.csv", name:"Neponsit", num:"9 reviews", pos:"Average 'positive sentiment' per review: 70.27", stars:"Average star rating: 5.0"}
{key:"newbrighton", file:"newbrighton.csv", name:"New Brighton", num:"110 reviews", pos:"Average 'positive sentiment' per review: 66.22", stars:"Average star rating: 4.34"}
{key:"newdorpbeach", file:"newdorpbeach.csv", name:"New Dorp Beach", num:"39 reviews", pos:"Average 'positive sentiment' per review: 69.56", stars:"Average star rating: 4.66"}
{key:"newspringville", file:"newspringville.csv", name:"New Springville", num:"24 reviews", pos:"Average 'positive sentiment' per review: 70.55", stars:"Average star rating: 4.76"}
{key:"noho", file:"noho.csv", name:"NoHo", num:"1463 reviews", pos:"Average 'positive sentiment' per review: 69.5", stars:"Average star rating: 4.6"}
{key:"nolita", file:"nolita.csv", name:"Nolita", num:"2762 reviews", pos:"Average 'positive sentiment' per review: 69.75", stars:"Average star rating: 4.64"}
{key:"northriverdale", file:"northriverdale.csv", name:"North Riverdale", num:"70 reviews", pos:"Average 'positive sentiment' per review: 67.49", stars:"Average star rating: 4.7"}
{key:"norwood", file:"norwood.csv", name:"Norwood", num:"127 reviews", pos:"Average 'positive sentiment' per review: 68.25", stars:"Average star rating: 4.76"}
{key:"oakwood", file:"oakwood.csv", name:"Oakwood", num:"92 reviews", pos:"Average 'positive sentiment' per review: 66.89", stars:"Average star rating: 4.55"}
{key:"ozonepark", file:"ozonepark.csv", name:"Ozone Park", num:"283 reviews", pos:"Average 'positive sentiment' per review: 68.1", stars:"Average star rating: 4.76"}
{key:"parkslope", file:"parkslope.csv", name:"Park Slope", num:"5617 reviews", pos:"Average 'positive sentiment' per review: 69.64", stars:"Average star rating: 4.7"}
{key:"parkchester", file:"parkchester.csv", name:"Parkchester", num:"191 reviews", pos:"Average 'positive sentiment' per review: 67.22", stars:"Average star rating: 4.5"}
{key:"pelhambay", file:"pelhambay.csv", name:"Pelham Bay", num:"84 reviews", pos:"Average 'positive sentiment' per review: 67.23", stars:"Average star rating: 4.39"}
{key:"pelhamgardens", file:"pelhamgardens.csv", name:"Pelham Gardens", num:"98 reviews", pos:"Average 'positive sentiment' per review: 68.53", stars:"Average star rating: 4.79"}
{key:"portmorris", file:"portmorris.csv", name:"Port Morris", num:"180 reviews", pos:"Average 'positive sentiment' per review: 67.44", stars:"Average star rating: 4.64"}
{key:"portrichmond", file:"portrichmond.csv", name:"Port Richmond", num:"5 reviews", pos:"Average 'positive sentiment' per review: 64.45", stars:"Average star rating: 4.6"}
{key:"prospectheights", file:"prospectheights.csv", name:"Prospect Heights", num:"3894 reviews", pos:"Average 'positive sentiment' per review: 69.26", stars:"Average star rating: 4.66"}
{key:"prospect-leffertsgardens", file:"prospect-leffertsgardens.csv", name:"Prospect-Lefferts Gardens", num:"3794 reviews", pos:"Average 'positive sentiment' per review: 67.6", stars:"Average star rating: 4.59"}
{key:"queensvillage", file:"queensvillage.csv", name:"Queens Village", num:"181 reviews", pos:"Average 'positive sentiment' per review: 68.96", stars:"Average star rating: 4.66"}
{key:"randallmanor", file:"randallmanor.csv", name:"Randall Manor", num:"115 reviews", pos:"Average 'positive sentiment' per review: 68.38", stars:"Average star rating: 4.5"}
{key:"redhook", file:"redhook.csv", name:"Red Hook", num:"504 reviews", pos:"Average 'positive sentiment' per review: 68.75", stars:"Average star rating: 4.62"}
{key:"regopark", file:"regopark.csv", name:"Rego Park", num:"357 reviews", pos:"Average 'positive sentiment' per review: 69.09", stars:"Average star rating: 4.74"}
{key:"richmondhill", file:"richmondhill.csv", name:"Richmond Hill", num:"644 reviews", pos:"Average 'positive sentiment' per review: 67.3", stars:"Average star rating: 4.64"}
{key:"richmondtown", file:"richmondtown.csv", name:"Richmondtown", num:"7 reviews", pos:"Average 'positive sentiment' per review: 64.24", stars:"Average star rating: 4.55"}
{key:"ridgewood", file:"ridgewood.csv", name:"Ridgewood", num:"2675 reviews", pos:"Average 'positive sentiment' per review: 68.08", stars:"Average star rating: 4.59"}
{key:"riverdale", file:"riverdale.csv", name:"Riverdale", num:"142 reviews", pos:"Average 'positive sentiment' per review: 67.59", stars:"Average star rating: 4.81"}
{key:"rockawaybeach", file:"rockawaybeach.csv", name:"Rockaway Beach", num:"130 reviews", pos:"Average 'positive sentiment' per review: 71.78", stars:"Average star rating: 4.72"}
{key:"rooseveltisland", file:"rooseveltisland.csv", name:"Roosevelt Island", num:"512 reviews", pos:"Average 'positive sentiment' per review: 68.1", stars:"Average star rating: 4.6"}
{key:"rosebank", file:"rosebank.csv", name:"Rosebank", num:"4 reviews", pos:"Average 'positive sentiment' per review: 65.89", stars:"Average star rating: 4.75"}
{key:"rosedale", file:"rosedale.csv", name:"Rosedale", num:"59 reviews", pos:"Average 'positive sentiment' per review: 68.57", stars:"Average star rating: 4.61"}
{key:"schuylerville", file:"schuylerville.csv", name:"Schuylerville", num:"2 reviews", pos:"Average 'positive sentiment' per review: 69.22", stars:"Average star rating: 5.0"}
{key:"sheepsheadbay", file:"sheepsheadbay.csv", name:"Sheepshead Bay", num:"295 reviews", pos:"Average 'positive sentiment' per review: 68.57", stars:"Average star rating: 4.65"}
{key:"shoreacres", file:"shoreacres.csv", name:"Shore Acres", num:"79 reviews", pos:"Average 'positive sentiment' per review: 66.36", stars:"Average star rating: 4.6"}
{key:"silverlake", file:"silverlake.csv", name:"Silver Lake", num:"16 reviews", pos:"Average 'positive sentiment' per review: 70.84", stars:"Average star rating: 4.88"}
{key:"soho", file:"soho.csv", name:"SoHo", num:"4996 reviews", pos:"Average 'positive sentiment' per review: 69.28", stars:"Average star rating: 4.62"}
{key:"soundview", file:"soundview.csv", name:"Soundview", num:"51 reviews", pos:"Average 'positive sentiment' per review: 65.84", stars:"Average star rating: 4.68"}
{key:"southbeach", file:"southbeach.csv", name:"South Beach", num:"50 reviews", pos:"Average 'positive sentiment' per review: 67.75", stars:"Average star rating: 4.54"}
{key:"southozonepark", file:"southozonepark.csv", name:"South Ozone Park", num:"152 reviews", pos:"Average 'positive sentiment' per review: 66.62", stars:"Average star rating: 4.35"}
{key:"southslope", file:"southslope.csv", name:"South Slope", num:"3142 reviews", pos:"Average 'positive sentiment' per review: 69.46", stars:"Average star rating: 4.72"}
{key:"springfieldgardens", file:"springfieldgardens.csv", name:"Springfield Gardens", num:"219 reviews", pos:"Average 'positive sentiment' per review: 66.99", stars:"Average star rating: 4.36"}
{key:"spuytenduyvil", file:"spuytenduyvil.csv", name:"Spuyten Duyvil", num:"19 reviews", pos:"Average 'positive sentiment' per review: 72.06", stars:"Average star rating: 4.55"}
{key:"st.albans", file:"st.albans.csv", name:"St. Albans", num:"265 reviews", pos:"Average 'positive sentiment' per review: 68.34", stars:"Average star rating: 4.56"}
{key:"st.george", file:"st.george.csv", name:"St. George", num:"477 reviews", pos:"Average 'positive sentiment' per review: 66.32", stars:"Average star rating: 4.59"}
{key:"stapleton", file:"stapleton.csv", name:"Stapleton", num:"71 reviews", pos:"Average 'positive sentiment' per review: 67.17", stars:"Average star rating: 4.76"}
{key:"stuyvesanttown", file:"stuyvesanttown.csv", name:"Stuyvesant Town", num:"1031 reviews", pos:"Average 'positive sentiment' per review: 69.09", stars:"Average star rating: 4.62"}
{key:"sunnyside", file:"sunnyside.csv", name:"Sunnyside", num:"1742 reviews", pos:"Average 'positive sentiment' per review: 67.91", stars:"Average star rating: 4.71"}
{key:"sunsetpark", file:"sunsetpark.csv", name:"Sunset Park", num:"1823 reviews", pos:"Average 'positive sentiment' per review: 67.31", stars:"Average star rating: 4.54"}
{key:"theaterdistrict", file:"theaterdistrict.csv", name:"Theater District", num:"1906 reviews", pos:"Average 'positive sentiment' per review: 68.21", stars:"Average star rating: 4.62"}
{key:"throgsneck", file:"throgsneck.csv", name:"Throgs Neck", num:"10 reviews", pos:"Average 'positive sentiment' per review: 71.6", stars:"Average star rating: 4.92"}
{key:"todthill", file:"todthill.csv", name:"Todt Hill", num:"12 reviews", pos:"Average 'positive sentiment' per review: 67.72", stars:"Average star rating: 4.92"}
{key:"tompkinsville", file:"tompkinsville.csv", name:"Tompkinsville", num:"253 reviews", pos:"Average 'positive sentiment' per review: 67.58", stars:"Average star rating: 4.6"}
{key:"tottenville", file:"tottenville.csv", name:"Tottenville", num:"13 reviews", pos:"Average 'positive sentiment' per review: 75.54", stars:"Average star rating: 4.85"}
{key:"tremont", file:"tremont.csv", name:"Tremont", num:"28 reviews", pos:"Average 'positive sentiment' per review: 66.22", stars:"Average star rating: 4.61"}
{key:"tribeca", file:"tribeca.csv", name:"Tribeca", num:"1060 reviews", pos:"Average 'positive sentiment' per review: 69.62", stars:"Average star rating: 4.74"}
{key:"twobridges", file:"twobridges.csv", name:"Two Bridges", num:"602 reviews", pos:"Average 'positive sentiment' per review: 67.6", stars:"Average star rating: 4.61"}
{key:"unionport", file:"unionport.csv", name:"Unionport", num:"7 reviews", pos:"Average 'positive sentiment' per review: 67.48", stars:"Average star rating: 5.0"}
{key:"universityheights", file:"universityheights.csv", name:"University Heights", num:"78 reviews", pos:"Average 'positive sentiment' per review: 67.38", stars:"Average star rating: 4.72"}
{key:"uppereastside", file:"uppereastside.csv", name:"Upper East Side", num:"16050 reviews", pos:"Average 'positive sentiment' per review: 67.38", stars:"Average star rating: 4.56"}
{key:"upperwestside", file:"upperwestside.csv", name:"Upper West Side", num:"18692 reviews", pos:"Average 'positive sentiment' per review: 67.95", stars:"Average star rating: 4.63"}
{key:"vannest", file:"vannest.csv", name:"Van Nest", num:"2 reviews", pos:"Average 'positive sentiment' per review: 63.27", stars:"Average star rating: 4.5"}
{key:"vinegarhill", file:"vinegarhill.csv", name:"Vinegar Hill", num:"336 reviews", pos:"Average 'positive sentiment' per review: 70.52", stars:"Average star rating: 4.8"}
{key:"wakefield", file:"wakefield.csv", name:"Wakefield", num:"19 reviews", pos:"Average 'positive sentiment' per review: 66.82", stars:"Average star rating: 4.68"}
{key:"washingtonheights", file:"washingtonheights.csv", name:"Washington Heights", num:"6174 reviews", pos:"Average 'positive sentiment' per review: 67.57", stars:"Average star rating: 4.58"}
{key:"westbrighton", file:"westbrighton.csv", name:"West Brighton", num:"3 reviews", pos:"Average 'positive sentiment' per review: 66.24", stars:"Average star rating: 4.67"}
{key:"westfarms", file:"westfarms.csv", name:"West Farms", num:"5 reviews", pos:"Average 'positive sentiment' per review: 73.91", stars:"Average star rating: 4.0"}
{key:"westvillage", file:"westvillage.csv", name:"West Village", num:"9789 reviews", pos:"Average 'positive sentiment' per review: 69.78", stars:"Average star rating: 4.66"}
{key:"westchestersquare", file:"westchestersquare.csv", name:"Westchester Square", num:"20 reviews", pos:"Average 'positive sentiment' per review: 66.97", stars:"Average star rating: 4.31"}
{key:"whitestone", file:"whitestone.csv", name:"Whitestone", num:"2 reviews", pos:"Average 'positive sentiment' per review: 73.92", stars:"Average star rating: 5.0"}
{key:"williamsbridge", file:"williamsbridge.csv", name:"Williamsbridge", num:"92 reviews", pos:"Average 'positive sentiment' per review: 68.77", stars:"Average star rating: 4.57"}
{key:"williamsburg", file:"williamsburg.csv", name:"Williamsburg", num:"42608 reviews", pos:"Average 'positive sentiment' per review: 69.62", stars:"Average star rating: 4.65"}
{key:"windsorterrace", file:"windsorterrace.csv", name:"Windsor Terrace", num:"980 reviews", pos:"Average 'positive sentiment' per review: 68.88", stars:"Average star rating: 4.68"}
{key:"woodhaven", file:"woodhaven.csv", name:"Woodhaven", num:"489 reviews", pos:"Average 'positive sentiment' per review: 67.32", stars:"Average star rating: 4.61"}
{key:"woodlawn", file:"woodlawn.csv", name:"Woodlawn", num:"111 reviews", pos:"Average 'positive sentiment' per review: 68.66", stars:"Average star rating: 4.61"}
{key:"woodside", file:"woodside.csv", name:"Woodside", num:"995 reviews", pos:"Average 'positive sentiment' per review: 67.47", stars:"Average star rating: 4.74"}
]

# ---
# jQuery document ready.
# ---
$ ->
  # create a new Bubbles chart
  plot = Bubbles()

  # ---
  # function that is called when
  # data is loaded
  # ---
  display = (data) ->
    plotData("#vis", data, plot)

  # we are storing the current text in the search component
  # just to make things easy
  key = decodeURIComponent(location.search).replace("?","")
  text = texts.filter((t) -> t.key == key)[0]

  # default to the first text if something gets messed up
  if !text
    text = texts[0]

  # select the current text in the drop-down
  $("#text-select").val(key)

  # bind change in jitter range slider
  # to update the plot's jitter
  d3.select("#jitter")
    .on "input", () ->
      plot.jitter(parseFloat(this.output.value))

  # bind change in drop down to change the
  # search url and reset the hash url
  d3.select("#text-select")
    .on "change", (e) ->
      key = $(this).val()
      location.replace("#")
      location.search = encodeURIComponent(key)

  # set the book title from the text name
  d3.select("#book-title").html(text.name)

  # set the number of reviews, positvity score, star count, from the text number of reviews
  d3.select("#num-reviews").html(text.num)

  d3.select("#stars").html(text.stars)
  d3.select("#pos").html(text.pos)

  # load our data
  d3.csv("data/#{text.file}", display)
