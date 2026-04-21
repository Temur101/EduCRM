import { createI18n } from 'vue-i18n';
import en from './locales/en.json';
import ru from './locales/ru.json';
import uz from './locales/uz.json';

const i18n = createI18n({
    legacy: false, // Use Composition API
    locale: localStorage.getItem('lang') || 'en', // Default locale
    fallbackLocale: 'en',
    messages: {
        en: {
            ...en,
            archive: {
                title: 'Archive',
                student: 'Students',
                teacher: 'Teachers',
                group: 'Groups',
                task: 'Tasks',
                board: 'Boards',
                payment: 'Payments'
            }
        },
        ru: {
            ...ru,
            archive: {
                title: 'Архив',
                subtitle: 'Управление удаленными записями',
                student: 'Студенты',
                teacher: 'Учителя',
                group: 'Группы',
                task: 'Задачи',
                board: 'Доски',
                payment: 'Платежи',
                searchPlaceholder: 'Поиск в архиве...',
                detailsTitle: 'Детали архивной записи',
                history: 'История',
                noComments: 'Нет комментариев',
                readOnly: 'Запись находится в архиве и доступна только для чтения',
                restoreTo: 'Восстановить в список',
                type: 'Тип',
                contentTitle: 'Название / Описание',
                archivedAt: 'Дата удаления',
                actions: 'Действия',
                clearTitle: 'Очистить архив?',
                clearWarning: 'Вы уверены, что хотите безвозвратно удалить ВСЕ записи из архива? Это действие нельзя отменить.',
                clearConfirm: 'Удалить всё',
                clearCancel: 'Отмена',
                empty: 'Архив пуст',
                fields: {
                    student: 'Студент',
                    amount: 'Сумма',
                    type: 'Тип транзакции',
                    method: 'Метод оплаты',
                    month: 'За месяц',
                    payment: 'Оплата',
                    refund: 'Возврат',
                    name: 'ФИО / Название',
                    phone: 'Номер телефона',
                    group: 'Группа',
                    status: 'Статус'
                }
            }
        },
        uz: {
            ...uz,
            archive: {
                title: 'Arxiv',
                subtitle: 'Oʻchirilgan yozuvlarni boshqarish',
                student: 'Talabalar',
                teacher: 'Oʻqituvchilar',
                group: 'Guruhlar',
                task: 'Vazifalar',
                board: 'Doskalar',
                payment: 'Toʻlovlar',
                searchPlaceholder: 'Arxivdan qidirish...',
                detailsTitle: 'Arxiv yozuvi tafsilotlari',
                history: 'Tarix',
                noComments: 'Izohlar yoʻq',
                readOnly: 'Yozuv arxivda va faqat oʻqish uchun mavjud',
                restoreTo: 'Roʻyxatga tiklash',
                type: 'Turi',
                contentTitle: 'Nomi / Tavsifi',
                archivedAt: 'Oʻchirilgan sana',
                actions: 'Harakatlar',
                clearTitle: 'Arxivni tozalamoqchimisiz?',
                clearWarning: 'Arxivdagi BARCHA yozuvlarni qaytarmasdan oʻchirishga ishonchingiz komilmi? Bu harakatni bekor qilib boʻlmaydi.',
                clearConfirm: 'Hammasini oʻchirish',
                clearCancel: 'Bekor qilish',
                empty: 'Arxiv boʻsh',
                fields: {
                    student: 'Talaba',
                    amount: 'Summa',
                    type: 'Tranzaksiya turi',
                    method: 'Toʻlov usuli',
                    month: 'Oy uchun',
                    payment: 'Toʻlov',
                    refund: 'Qaytarish',
                    name: 'FIO / Nomi',
                    phone: 'Telefon raqami',
                    group: 'Guruh',
                    status: 'Status'
                }
            }
        }
    },
});

export default i18n;
