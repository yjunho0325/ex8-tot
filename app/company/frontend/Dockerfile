FROM nginx:1.31.3-alpine

RUN rm -rf /etc/nginx/conf.d/default.conf
COPY ./app/company/frontend/default.conf /etc/nginx/conf.d/default.conf
COPY ./app/company/frontend/html /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]