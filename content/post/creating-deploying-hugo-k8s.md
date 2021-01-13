---
author: "Curtis John"
title: "Create and Deploy Hugo to Kubernetes"
image: "img/posts/creating-deploying-hugo.png"
draft: false
date: 2021-01-09
description: "Deploy Hugo Site Using Helm"
tags: ["hugo", "k8s", "helm"]
archives: ["2021/01"]
---

# Intro

This isn't the first iteration of this blog. Prior to using Hugo I was using Ghost. I loved Ghost as an all-in-one CMS solution. It is simple, fairly lightweight, and easy to get the hang of. This was very early on in my sysadmin career, so backups were non-existent. As you can imagine, all it took for that to go wrong was a couple of dead drives combined with a dead RAID card.

If you fast forward a few years to 2020, you get the most recent iteration of my homelab which is backed fully by [gitops](https://www.gitops.tech/#what-is-gitops) and [infrastructure as code](https://www.hashicorp.com/resources/what-is-infrastructure-as-code). I only need to take backups of the most criticial pieces of information (databases, photos, music, etc.). Limiting the use of stateful VMs and pivoting to a container-centric environment has allowed me to teach myself in the most effective way possible: break and fix. When I break something with my Kubernetes cluster I'm minutes away from having a fresh install. I can spin up applications on demand and decide if I like them or not. I can restore from backups in seconds. It is legitimately a tinkerer's paradise.

Enter: Hugo

## Picking Hugo

For those uninitiated, [Hugo](https://gohugo.io) is an open-source static site generator written in Go. Essentially it consumes human-readable markdown and spits out a full HTML website. This makes it easy to rapidly create fully-featured websites.

Hugo was appealing for multiple reasons including simplicity, conducive to a gitops approach, and a new challenge. I knew from the onset that I wanted to try and build and deploy this without having to do much external searching or Googling. Thankfully the Hugo docs are pretty good, and I already had experience working with Docker.

# My Setup

This is going to be _my_ journey to building _this_ blog. You may not have the same end goals as I do, or you may use a different approach to creating your Hugo site. Either way please feel free to modify these instructions to build your own website, or fork/copy the [repo](https://github.com/crutonjohn/baremetalblog) where this blog lives!

### Downloading Hugo

Since Hugo is written in Go the only requirement to install it is to have the binary in your `$PATH`.

- Mac:
```bash
brew install hugo
```
- Linux
```bash
export HUGO_VERSION=0.79.0

curl -O -L https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz /tmp/ && \
    tar -xf /tmp/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/hugo
```

### Create a Git Repo

I'm going to assume you'll know how to do this. You can either create one on Github/Gitlab/etc. and clone it, or just create a repo locally and then push it to a remote later on.

```bash
git clone git@github.com:crutonjohn/baremetalblog.git
```

### Finding and Installing a Theme

I wanted to find a theme that was simple, had a dark mode built-in, and is readable. I found [Blonde](https://github.com/opera7133/Blonde) which looked perfect to me.

First we need to install Node.js:

```bash
brew install node
```

Then we need to install some npm packages:

```bash
npm install -g postcss
npm install -g postcss-cli
npm install -g autoprefixer
```

Continuing with the directions for Blonde, I need to add a git submodule to my repo:

```bash
cd baremetalblog
git submodule add https://github.com/opera7133/Blonde.git themes/Blonde
mv themes/Blonde/exampleSite/* ./
```

Now your site is initialized with some example data from the theme itself. The example pages give some detail on how to create pages with different types of content and thumbnails, so it may be benificial to read through those.

The final theme installation step is to `cd` into the theme's directory and install it with node:

```bash
cd themes/Blonde
npm install
```

### Generating the Example Site

If you've made it this far, the root of your git repo should look something like this:

```
baremetalblog/
├── .git
├── .gitmodules
├── archetypes
├── config.toml
├── configTaxo.toml
├── content
├── layouts
├── package.json
├── static
└── themes
```

At the root of your blog's repo, run:

```bash
hugo
```

This _should_ generate your site giving you some buffer output like so:

```bash
hugo
Start building sites … 

                   | EN  
-------------------+-----
  Pages            | 54  
  Paginator pages  |  2  
  Non-page files   |  0  
  Static files     | 18  
  Processed images |  0  
  Aliases          | 26  
  Sitemaps         |  1  
  Cleaned          |  0  

Total in 4905 ms
```

However, with the Blonde theme I chose, there was an error regarding the Instagram Shortcode integration, so I deleted the shortcode in [rich-content.md](https://github.com/opera7133/Blonde/blob/master/exampleSite/content/post/rich-content.md). Specifically line 19.

Your site will be generated and put into `public/` in the root of your repo. These are the files that will be put into nginx in order to serve your site.

### Editing Your Site

#### hugo server

Hugo is not only a site generator, it also provides you a way to serve your site in addition to a way to live edit your site. In the root of your repo run the following:

```bash
hugo server
```

This will compile your site in memory, and serve it on `http://localhost:1313`. When you make changes to files and save them the site is rebuilt in real-time reflecting your edits.

#### Changing Your config.toml

Upon building your site, `hugo` immediately reads a file at the root of the project called `config.toml`. Since we copied the example site earlier this file will already exist, but _will_ require some edits to make it usable in production. Check out [Configure Hugo](https://gohugo.io/getting-started/configuration/) from the official docs for a breakdown of the settings.

At the very least you'll want to edit the top section of the file to be more in line with your preferences:

```toml
baseURL = "https://example.com"
title = "Blonde"
author = "wamo"
languageCode = "en"
DefaultContentLanguage = "en"
enableInlineShortcodes = true
```

### Containerizing and Deploying Your Site

For my personal usage, I have decided to build a container by hand to keep everything in the same repo. This may or may not work for you.

#### Creating Dockerfile

For my Docker build process I decided to run Alpine in order to build the site:

```Dockerfile
FROM alpine:latest as MEATGRINDER
# generate hugo site
ENV HUGO_VERSION=0.79.0
COPY ./ /site/
# install hugo
ADD https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz /tmp/
RUN tar -xf /tmp/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/hugo && \
    # install npm
    apk add --update npm && \
    # install npm packages
    npm install -g postcss && \
    npm install -g postcss-cli && \
    npm install -g autoprefixer && \
    # install hugo theme with npm
    npm install /site/themes/Blonde && \
    # generate site
    hugo -s /site
```

And then immediately follow that up with copying the site content to an Alpine Nginx container:

```Dockerfile
# serve site with nginx
FROM nginx:stable-alpine
RUN apk --update add curl bash
# copy custom config for site
COPY meta/nginx/bmb.conf /etc/nginx/conf.d/bmb.conf
# copy site content from first container
COPY --from=MEATGRINDER /site/public/ /usr/share/nginx/html/
EXPOSE 80
```

You'll notice that in the second part of the Dockerfile that I am copying an Nginx config file from my repo. This file points Nginx to the files for my site:

```
server {
       listen 80;
       listen [::]:80;

       root /usr/share/nginx/html/; 
       index index.html;

       location / {
               try_files $uri $uri/ =404;
       }
}
```

#### Building the Docker Container

Once again make sure that you are in the root of your project and simply run:

```bash
docker build -t myname/mycoolsite:dev .
```

This should start building your container. If there are any errors, you'll likely need to tweak your Dockerfile to do some troubleshooting.

Now that the image is built, we should run it locally to see that everything is loading correctly:

```bash
docker run -p 80:80 --rm myname/mycoolsite:dev
```

Now in your web browser navigate to `http://localhost` and make sure that your site functions as expected.

Sweet, now we have a Hugo site containerized!

### Creating a Helm Chart to Deploy to Kubernetes

[Helm](https://helm.sh/) has been dubbed the "package manager for Kubernetes". It is a way to install software and associated resources to a Kubernetes cluster by using the powerful Go templating engine and lots of YAML. In order to simplify my blog deployment to my Kubernetes cluster I want to create a Helm chart for use with [Flux](https://fluxcd.io/) in my gitops workflow.

#### Initialize the Helm chart

