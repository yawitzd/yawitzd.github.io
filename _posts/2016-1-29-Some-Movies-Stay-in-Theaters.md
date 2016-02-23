---
layout: post
title: Some movies stay in theaters for a long time
---

First of all, do you know how easy it is to scrape text from an HTML page? [Selenium](http://www.seleniumhq.org/) and [Beautiful Soup](http://www.crummy.com/software/BeautifulSoup/bs4/doc/) make it almost unfair. It helps when the page is built simply, like Box Office Mojo.

![Here's to you, divs, tables, and simple URLs.](images/posts/02-bom.png)

With that in mind, I pulled data from all 15,000 movies in the [Box Office Mojo](http://www.boxofficemojo.com/movies/alphabetical.htm?letter=A&p=.htm) database. Almost all movies have numbers on box office performance (clearly), open date, close date, oscar recognition, budget, runtime, cast, crew, and size of release.

I ran a quick logistic regression on a subset of that data to see if I could predict how long a movie would stay in theaters. I decided to only look at movies in wide release (600 or more theaters), which meant cutting out a sizable chunk of data. Only 8300 movies have an open and close date, and of those only 2200 were released in more than 600 theaters (apparently most movies get released in fewer than 50 theaters?).

(I also cut out movies that were in theaters for longer than a year. In case you forgot, *Encounter in the Third Dimension* ran for 7 years in IMAX theaters between 1999 and 2006.)

Here's the data I was left with:

![Scatter matrices get me pumped](images/posts/02_movies_matrix.png =250x)

The most linear relationships I found between these points and time spent in theaters ('days') were from opening weekend gross and Metacritic score (pulled in from [OMDB](http://www.omdbapi.com/)). I took the log of the first two features (to distribute them a bit more normally). A regression run on each of those features looked like this:

![Lots of numbers look impressive](02_weekend_gross_and_metacritic.png =250x)

A multi linear model on those two variables spat out an R-squared value of 0.465. That's not much to bet on, but it's not bad for two features. If a big movie tanks on opening weekend and has lousy reviews, don't expect it to stay in theaters very long.

More insights coming soon. Code for this project is on [GitHub](http://www.github.com/yawitzd).
