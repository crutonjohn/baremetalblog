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
    npm i -D @fullhuman/postcss-purgecss postcss && \
    # install hugo theme with npm
    npm install /site/themes/Blonde && \
    # generate site
    hugo -s /site

# serve site with nginx
FROM nginx:stable-alpine
RUN apk --update add curl bash
# copy custom config for site
COPY meta/nginx/bmb.conf /etc/nginx/conf.d/bmb.conf
# copy site content from first container
COPY --from=MEATGRINDER /site/public/ /usr/share/nginx/html/
EXPOSE 80