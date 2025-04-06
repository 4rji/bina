import scrapy

class SiteDownloaderSpider(scrapy.Spider):
    name = 'site_downloader'
    
    def start_requests(self):
        url = input("Ingrese la dirección del sitio web: ")
        yield scrapy.Request(url=url, callback=self.parse)

    def parse(self, response):
        page = response.url.split("/")[-2]
        filename = f'{page}.html'
        with open(filename, 'wb') as f:
            f.write(response.body)
        self.log(f'Se guardó el archivo {filename}')

        # Rastrear enlaces adicionales (simplificado, solo para demostración)
        for href in response.css('a::attr(href)').getall():
            if href.startswith("http"):
                yield response.follow(href, self.parse)
